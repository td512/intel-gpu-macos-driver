// SPDX-License-Identifier: MIT
// pcode_test: offline check of the pcode mailbox and power-limit path's pure parts (xe_pcode.h), no GPU needed.
//   1. registers, commands and fields equal Linux xe_pcode_api.h, xe_pcode.h and regs/xe_mchbar_regs.h
//   2. pcode_mailbox_status's error decoding (xe_pcode.c:38-71)
//   3. __pcode_mailbox_rw (xe_pcode.c:73-102) against a fake pcode: write order, read-back, busy mailbox, an absent
//      device, the timeout and its total wait, __xe_mmio_wait32's last read (xe_mmio.c:361-370), error replies
//   4. unit scaling of the limit words (xe_hwmon.c:361-362, :585-601, :903-904) and the report text
//   5. the descriptor: BMG (G21 and G31) has mailbox power limits (xe_pci.c:421); no other family here does
// c++ -std=c++17 -Wall -Wextra -I.. -o pcode_test pcode_test.cpp ../xe_platform.cpp && ./pcode_test
#include <stdio.h>
#include <string.h>
#include <vector>
#include "xe_platform.h"
#include "xe_pcode.h"

static int fails, checks;
#define CHECK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); \
	printf("\n"); } } while (0)

// A pcode behind PCODE_MAILBOX/DATA0/DATA1: a command written with READY stays busy for `busyReads` mailbox reads, then
// READY clears, the error field holds `error` and DATA0/DATA1 hold the reply.
struct FakePcode {
	uint32_t mailbox {0}, data0 {0}, data1 {0};
	uint32_t busyReads {2}, error {PCODE_SUCCESS}, reply0 {0}, reply1 {0};
	bool absent {false};        // the device does not answer: every read is all ones
	bool neverDone {false};     // READY never clears
	uint32_t busyLeft {0};
	uint64_t waitedUs {0};
	std::vector<std::pair<uint32_t, uint32_t>> writes;
	uint32_t rd(uint32_t off) {
		if (absent) return 0xffffffffu;
		if (off == PCODE_MAILBOX) {
			if ((mailbox & PCODE_READY) && !neverDone) {
				if (busyLeft) busyLeft--;
				else {
					mailbox = error;   // READY clear, error code in 7:0
					data0 = reply0;
					data1 = reply1;
				}
			}
			return mailbox;
		}
		return off == PCODE_DATA0 ? data0 : off == PCODE_DATA1 ? data1 : 0xdeadbeefu;
	}
	void wr(uint32_t off, uint32_t v) {
		writes.push_back({off, v});
		if (off == PCODE_MAILBOX) mailbox = v, busyLeft = busyReads;
		else if (off == PCODE_DATA0) data0 = v;
		else if (off == PCODE_DATA1) data1 = v;
	}
	void delayUs(uint32_t us) { waitedUs += us; }
};

int main() {
	// 1. constants
	CHECK(PCODE_MAILBOX == 0x138124 && PCODE_DATA0 == 0x138128 && PCODE_DATA1 == 0x13812c, "mailbox registers");
	CHECK(PCODE_READY == 0x80000000u && PCODE_ERROR_MASK == 0xff, "READY bit 31, error 7:0");
	CHECK(PCODE_POWER_SETUP == 0x7c && POWER_SETUP_SUBCOMMAND_READ_I1 == 4, "PCODE_POWER_SETUP, READ_I1");
	CHECK(READ_PSYSGPU_POWER_LIMIT == 6 && READ_PACKAGE_POWER_LIMIT == 8, "card / package power-limit subcommands");
	CHECK(READ_PL_FROM_PCODE == 0 && READ_PL_FROM_FW == 1 && READ_PL_ACCEPTED == 2, "param2 of the limit reads");
	CHECK(DGFX_PCODE_STATUS == 0x7e && DGFX_GET_INIT_STATUS == 0 && DGFX_INIT_STATUS_COMPLETE == 1, "init status");
	CHECK(PCODE_DEFAULT_TIMEOUT_MS == 10, "xe_pcode_read timeout");
	CHECK(PWR_LIM_VAL == 0x7fff && PWR_LIM_EN == 0x8000, "PWR_LIM_VAL 14:0, PWR_LIM_EN 15");
	CHECK(XE_PWR_UNIT_MBX == 3 && XE_TIME_UNIT_MBX == 10, "PWR_UNIT 0x3, TIME_UNIT 0xa");
	CHECK(POWER_SETUP_I1_WATTS == 0x80000000u && POWER_SETUP_I1_SHIFT == 6 && POWER_SETUP_I1_DATA_MASK == 0xffff, "I1");
	CHECK(xePcodeMbox(PCODE_POWER_SETUP, READ_PSYSGPU_POWER_LIMIT, READ_PL_FROM_FW) == 0x01067c, "PCODE_MBOX 0x%06x",
		xePcodeMbox(PCODE_POWER_SETUP, READ_PSYSGPU_POWER_LIMIT, READ_PL_FROM_FW));
	CHECK(xePcodeMbox(PCODE_POWER_SETUP, READ_PACKAGE_POWER_LIMIT, READ_PL_FROM_PCODE) == 0x00087c, "package, from pcode");
	CHECK(xePcodeMbox(0x1ff, 0x1ff, 0x1ff) == 0xffffff, "fields masked to 8 bits");

	// 2. status
	struct { uint32_t code; int err; } st[] = {{PCODE_SUCCESS, 0}, {PCODE_ILLEGAL_CMD, ENXIO}, {PCODE_TIMEOUT, ETIMEDOUT},
		{PCODE_ILLEGAL_DATA, EINVAL}, {PCODE_ILLEGAL_SUBCOMMAND, ENXIO}, {PCODE_LOCKED, EBUSY},
		{PCODE_GT_RATIO_OUT_OF_RANGE, EOVERFLOW}, {PCODE_REJECTED, EACCES}, {0x5, EPROTO}, {0xff, EPROTO}};
	for (auto &t : st) CHECK(xePcodeStatusErrno(0x7c00u | t.code) == t.err, "status 0x%x -> %d", t.code, t.err);
	CHECK(xePcodeStatusErrno(0x01067c00u) == 0, "only bits 7:0 are the error");

	// 3. the mailbox protocol
	{
		FakePcode p;
		p.reply0 = 0x00038cf0u;
		p.reply1 = 0x00008708u;
		uint32_t d0 = 0, d1 = 0;
		const uint32_t mbox = xePcodeMbox(PCODE_POWER_SETUP, READ_PSYSGPU_POWER_LIMIT, READ_PL_FROM_FW);
		const int err = xePcodeMailboxRw(p, mbox, &d0, &d1, PCODE_DEFAULT_TIMEOUT_MS * 1000, true);
		CHECK(err == 0 && d0 == 0x00038cf0u && d1 == 0x00008708u, "read: err %d data 0x%08x 0x%08x", err, d0, d1);
		CHECK(p.writes.size() == 3 && p.writes[0] == std::make_pair(PCODE_DATA0, 0u) && p.writes[1] == std::make_pair(PCODE_DATA1, 0u) &&
			p.writes[2] == std::make_pair(PCODE_MAILBOX, PCODE_READY | mbox), "DATA0, DATA1, then MAILBOX = READY | mbox");
		CHECK(p.waitedUs == 10 + 20, "waits double from 10 us: %llu us", (unsigned long long)p.waitedUs);
	}
	{
		FakePcode p;   // the request goes in DATA0 (pcode_try_request); no DATA1 given: 0 is written
		uint32_t d0 = 0x12345678;
		xePcodeMailboxRw(p, DGFX_PCODE_STATUS, &d0, nullptr, 1000, true);
		CHECK(p.writes.size() == 3 && p.writes[0].second == 0x12345678 && p.writes[1].second == 0, "DATA0 request, DATA1 0");
	}
	{
		FakePcode p;   // busy before the request: -EAGAIN, nothing written
		p.mailbox = PCODE_READY | 0x7c;
		p.neverDone = true;
		uint32_t d0 = 0, d1 = 0;
		CHECK(xePcodeMailboxRw(p, 0x7c, &d0, &d1, 10000, true) == EAGAIN && p.writes.empty(), "busy mailbox: EAGAIN, no write");
	}
	{
		FakePcode p;   // a device that reads all ones
		p.absent = true;
		uint32_t d0 = 0;
		CHECK(xePcodeMailboxRw(p, 0x7c, &d0, nullptr, 10000, true) == EAGAIN && p.writes.empty(), "absent device: EAGAIN");
	}
	{
		FakePcode p;   // pcode never answers: ETIMEDOUT after exactly the timeout, data untouched
		p.neverDone = true;
		uint32_t d0 = 0xaaaa, d1 = 0xbbbb;
		const int err = xePcodeMailboxRw(p, 0x7c, &d0, &d1, PCODE_DEFAULT_TIMEOUT_MS * 1000, true);
		CHECK(err == ETIMEDOUT && p.waitedUs == 10000 && d0 == 0xaaaa && d1 == 0xbbbb, "timeout: err %d after %llu us", err,
			(unsigned long long)p.waitedUs);
	}
	{
		// the answer comes with the read after the deadline: success (xe_mmio.c:361-370). 10 ms in doubling waits from
		// 10 us is 10 waits (10+20+...+2560 = 5110, then 4890 to the deadline): 11 polls, then the last read.
		FakePcode p;
		p.busyReads = 11;
		p.reply0 = 7;
		uint32_t d0 = 0;
		const int err = xePcodeMailboxRw(p, 0x7c, &d0, nullptr, 10000, true);
		CHECK(err == 0 && d0 == 7 && p.waitedUs == 10000, "answer at the last read: err %d, waited %llu us", err,
			(unsigned long long)p.waitedUs);
	}
	{
		FakePcode p;   // an error reply: the data is read back, the error decoded
		p.error = PCODE_ILLEGAL_SUBCOMMAND;
		p.reply0 = 0x55;
		uint32_t d0 = 0;
		CHECK(xePcodeMailboxRw(p, 0x7c, &d0, nullptr, 10000, true) == ENXIO && d0 == 0x55, "illegal subcommand: ENXIO");
		FakePcode q;
		q.error = PCODE_LOCKED;
		uint32_t e0 = 0;
		CHECK(xePcodeMailboxRw(q, 0x7c, &e0, nullptr, 10000, false) == EBUSY && e0 == 0, "locked: EBUSY; no read-back asked");
	}

	// 4. units and text
	CHECK(xePowerLimitMw(PWR_LIM_EN | 190 * 8, XE_PWR_UNIT_MBX) == 190000, "190 W");
	CHECK(xePowerLimitMw(1, XE_PWR_UNIT_MBX) == 125, "one count = 1/8 W");
	CHECK(xePowerLimitMw(0xffffffffu, XE_PWR_UNIT_MBX) == 4095875, "only bits 14:0 count: %u mW",
		xePowerLimitMw(0xffffffffu, XE_PWR_UNIT_MBX));
	CHECK(xePowerLimitTauMs(10u << PWR_LIM_TIME_Y_SHIFT, XE_TIME_UNIT_MBX) == 1000, "x 0, y 10: 1 s");
	CHECK(xePowerLimitTauMs(3u << PWR_LIM_TIME_X_SHIFT | 12u << PWR_LIM_TIME_Y_SHIFT, XE_TIME_UNIT_MBX) == 7000,
		"x 3, y 12: 1.75 * 4 s");
	CHECK(xePowerLimitTauMs(0, XE_TIME_UNIT_MBX) == 0, "x 0, y 0: 4 / 4096 s rounds to 0 ms");
	CHECK(xePowerI1Milli(POWER_SETUP_I1_WATTS | 300u << 6) == 300000, "I1 300 W");
	CHECK(xePowerI1Milli(1) == 15, "I1 1/64: %u", xePowerI1Milli(1));

	XePowerLimits pl;
	char buf[512];
	size_t n = xePowerLimitsText(buf, sizeof buf, pl);
	CHECK(!strcmp(buf, ", power limits unavailable (pcode error 96)") && n == strlen(buf), "not read: %s", buf);
	pl.err = 0;
	pl.word[XE_PL_CARD][0] = PWR_LIM_EN | 190 * 8 | 10u << PWR_LIM_TIME_Y_SHIFT;
	pl.word[XE_PL_CARD][1] = 2 * 8 + 1;   // 2.125 W, off
	pl.word[XE_PL_PKG][0] = PWR_LIM_EN | (150 * 8 + 4);
	pl.word[XE_PL_PKG][1] = PWR_LIM_EN | 300 * 8;
	n = xePowerLimitsText(buf, sizeof buf, pl);
	CHECK(!strcmp(buf, ", card PL1 190 W (on), card PL2 2.125 W (off), package PL1 150.500 W (on), package PL2 300 W (on)"),
		"limits: %s", buf);
	pl.i1Err = 0;
	pl.i1 = POWER_SETUP_I1_WATTS | (400u << 6 | 32);
	n = xePowerLimitsText(buf, sizeof buf, pl);
	CHECK(n == strlen(buf) && strstr(buf, "package PL2 300 W (on), card crit 400.500 W") && buf[n - 1] == 'W', "I1 W: %s", buf);
	pl.i1 = 50u << 6;
	xePowerLimitsText(buf, sizeof buf, pl);
	CHECK(strstr(buf, ", card crit 50.000 A") != nullptr, "I1 without bit 31 is amperes: %s", buf);
	char small[24];
	memset(small, 'x', sizeof small);
	n = xePowerLimitsText(small, sizeof small, pl);
	CHECK(n == sizeof small - 1 && small[n] == 0 && !strncmp(small, ", card PL1 190 W (on), c", n), "cut to the buffer: %zu '%s'",
		n, small);
	CHECK(xePowerLimitsText(small, 0, pl) == 0, "no room: nothing");
	// the text must not look like the fields tools/regress and the app take the first match of
	pl.word[XE_PL_CARD][0] = PWR_LIM_EN | 190 * 8;
	xePowerLimitsText(buf, sizeof buf, pl);
	CHECK(!strstr(buf, "card power") && !strstr(buf, "package power") && !strstr(buf, " C,") && !strstr(buf, "MHz"),
		"no field names of the earlier text: %s", buf);

	// 5. descriptor
	for (uint32_t p = 0; p < kXePlatformCount; p++)
		CHECK(kXePlatforms[p].hasMbxPowerLimits == (kXePlatforms[p].platform == XE_BATTLEMAGE), "%s%s: has_mbx_power_limits",
			kXePlatforms[p].name, kXePlatforms[p].subplatform ? kXePlatforms[p].subplatform : "");
	CHECK(xePlatformFind(0xe20b)->hasMbxPowerLimits && xePlatformFind(0xe212)->hasMbxPowerLimits &&
		xePlatformFind(0xe223)->hasMbxPowerLimits, "B580, Pro B50, G31");

	printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
	return fails ? 1 : 0;
}
