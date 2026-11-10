// SPDX-License-Identifier: MIT
// The pcode mailbox as Linux drivers/gpu/drm/xe drives it, and the power-limit words xe_hwmon reads through it on
// platforms with has_mbx_power_limits (BMG, xe_pci.c:421). From Linux tree abf8c33 (v7.4 merge window): xe_pcode_api.h,
// xe_pcode.h, xe_pcode.c, xe_mmio.c __xe_mmio_wait32, regs/xe_mchbar_regs.h, xe_hwmon.c. Only the pure parts live here
// (register layout, the mailbox protocol over an MMIO accessor, error decoding, unit scaling, the report text) so that
// tests/pcode_test.cpp builds them on the host against a fake pcode; the lock, the MMIO and the reads are
// IntelXe::pcodeRead and IntelXe::powerLimitsRead. Read only: nothing here writes a power limit.
#pragma once
#include <stdint.h>
#include <sys/errno.h>
#ifdef KERNEL
#include <libkern/libkern.h>   // snprintf
#else
#include <stdio.h>
#endif

// xe_pcode_api.h:13-29
static constexpr uint32_t PCODE_MAILBOX = 0x138124;
static constexpr uint32_t PCODE_READY = 1u << 31;
static constexpr uint32_t PCODE_ERROR_MASK = 0xff;   // the error field shares bits 7:0 with PCODE_MB_COMMAND
enum : uint32_t {
	PCODE_SUCCESS = 0x0, PCODE_ILLEGAL_CMD = 0x1, PCODE_TIMEOUT = 0x2, PCODE_ILLEGAL_DATA = 0x3,
	PCODE_ILLEGAL_SUBCOMMAND = 0x4, PCODE_LOCKED = 0x6, PCODE_GT_RATIO_OUT_OF_RANGE = 0x10, PCODE_REJECTED = 0x11,
};
static constexpr uint32_t PCODE_DATA0 = 0x138128;
static constexpr uint32_t PCODE_DATA1 = 0x13812c;
// xe_pcode_api.h:37-39
static constexpr uint32_t DGFX_PCODE_STATUS = 0x7e, DGFX_GET_INIT_STATUS = 0, DGFX_INIT_STATUS_COMPLETE = 1;
// xe_pcode_api.h:42-47, 49-55
static constexpr uint32_t PCODE_POWER_SETUP = 0x7c;
static constexpr uint32_t POWER_SETUP_SUBCOMMAND_READ_I1 = 0x4;
static constexpr uint32_t POWER_SETUP_I1_WATTS = 1u << 31, POWER_SETUP_I1_SHIFT = 6, POWER_SETUP_I1_DATA_MASK = 0xffff;
static constexpr uint32_t READ_PSYSGPU_POWER_LIMIT = 0x6, READ_PACKAGE_POWER_LIMIT = 0x8;
static constexpr uint32_t READ_PL_FROM_PCODE = 0x0, READ_PL_FROM_FW = 0x1, READ_PL_ACCEPTED = 0x2;
// xe_pcode.h:21: xe_pcode_read's timeout
static constexpr uint32_t PCODE_DEFAULT_TIMEOUT_MS = 10;

// regs/xe_mchbar_regs.h:41-46: a power-limit word (PCU_CR_PACKAGE_RAPL_LIMIT layout; the mailbox returns PL1 in DATA0
// and PL2 in DATA1 in the same layout, xe_hwmon.c:211-214)
static constexpr uint32_t PWR_LIM_VAL = 0x7fff;   // 14:0
static constexpr uint32_t PWR_LIM_EN = 1u << 15;
static constexpr uint32_t PWR_LIM_TIME_X_SHIFT = 22, PWR_LIM_TIME_X_MASK = 0x3;    // 23:22
static constexpr uint32_t PWR_LIM_TIME_Y_SHIFT = 17, PWR_LIM_TIME_Y_MASK = 0x1f;   // 21:17
// xe_hwmon.c:79-85: the units of mailbox-power-limit platforms (PKG_POWER_SKU_UNIT does not exist there), as right
// shifts: power 1/8 W, time 1/1024 s (energy: XE_ENERGY_UNIT_MBX in xe_pmt.h). Set at :1526-1528.
static constexpr uint8_t XE_PWR_UNIT_MBX = 0x3, XE_TIME_UNIT_MBX = 0xa;

// xe_pcode.h:41-44 PCODE_MBOX: command 7:0, param1 15:8, param2 23:16 (xe_pcode_api.h:15-17)
static constexpr uint32_t xePcodeMbox(uint32_t cmd, uint32_t param1, uint32_t param2) {
	return (cmd & 0xff) | (param1 & 0xff) << 8 | (param2 & 0xff) << 16;
}

// xe_pcode.c:38-71 pcode_mailbox_status: the mailbox's error field as an errno (positive here), 0 on success
static inline int xePcodeStatusErrno(uint32_t mailbox) {
	switch (mailbox & PCODE_ERROR_MASK) {
	case PCODE_SUCCESS: return 0;
	case PCODE_ILLEGAL_CMD: return ENXIO;
	case PCODE_TIMEOUT: return ETIMEDOUT;
	case PCODE_ILLEGAL_DATA: return EINVAL;
	case PCODE_ILLEGAL_SUBCOMMAND: return ENXIO;
	case PCODE_LOCKED: return EBUSY;
	case PCODE_GT_RATIO_OUT_OF_RANGE: return EOVERFLOW;
	case PCODE_REJECTED: return EACCES;
	default: return EPROTO;
	}
}

// xe_pcode.c:73-102 __pcode_mailbox_rw, with xe_mmio.c:325-370 __xe_mmio_wait32 for the wait on READY. Io supplies
// uint32_t rd(uint32_t off), void wr(uint32_t off, uint32_t v) and void delayUs(uint32_t us). The caller holds the
// pcode lock (tile->pcode.lock, xe_pcode.c:111). EAGAIN when the mailbox is still busy (a device that does not answer
// reads all ones, READY included), ETIMEDOUT when pcode does not clear READY within timeoutUs, otherwise the decoded
// error field. With returnData, DATA0 (and DATA1 when data1 is given) are read back as xe_pcode_read does.
template <class Io>
static int xePcodeMailboxRw(Io &io, uint32_t mbox, uint32_t *data0, uint32_t *data1, uint32_t timeoutUs, bool returnData) {
	if (io.rd(PCODE_MAILBOX) & PCODE_READY) return EAGAIN;
	io.wr(PCODE_DATA0, *data0);
	io.wr(PCODE_DATA1, data1 ? *data1 : 0);
	io.wr(PCODE_MAILBOX, PCODE_READY | mbox);
	// __xe_mmio_wait32: poll with a wait that doubles from 10 us, never past the deadline, then one last read
	bool done = false;
	for (uint32_t waited = 0, wait = 10;;) {
		if (!(io.rd(PCODE_MAILBOX) & PCODE_READY)) {
			done = true;
			break;
		}
		if (waited >= timeoutUs) break;
		if (wait > timeoutUs - waited) wait = timeoutUs - waited;
		io.delayUs(wait);
		waited += wait;
		wait = wait < 50000 ? wait << 1 : wait;
	}
	if (!done && (io.rd(PCODE_MAILBOX) & PCODE_READY)) return ETIMEDOUT;
	if (returnData) {
		*data0 = io.rd(PCODE_DATA0);
		if (data1) *data1 = io.rd(PCODE_DATA1);
	}
	return xePcodeStatusErrno(io.rd(PCODE_MAILBOX));
}

// xe_hwmon.c:361-362: a power-limit word's value, REG_FIELD_GET(PWR_LIM_VAL) * SF_POWER >> scl_shift_power, here in
// milliwatts (SF_POWER / 1000; exact for the 1/8 W unit)
static inline uint32_t xePowerLimitMw(uint32_t word, uint8_t shift) {
	return (uint32_t)((uint64_t)(word & PWR_LIM_VAL) * 1000000u >> shift) / 1000u;
}
// xe_hwmon.c:585-601: the limit's time window in ms, tau = (1 + x/4) * 2^y units: (4 | x) << y, >> (time shift + 2)
static inline uint64_t xePowerLimitTauMs(uint32_t word, uint8_t timeShift) {
	const uint32_t x = word >> PWR_LIM_TIME_X_SHIFT & PWR_LIM_TIME_X_MASK, y = word >> PWR_LIM_TIME_Y_SHIFT & PWR_LIM_TIME_Y_MASK;
	return ((uint64_t)(4 | x) << y) * 1000u >> (timeShift + 2);
}
// xe_hwmon.c:891-908 with :1176 (power_crit, SF_POWER) or curr_crit (SF_CURR): I1 in U10.6, watts when bit 31 is set
// (xe_hwmon.c:855, 1133-1136), amperes otherwise; here milliwatts or milliamperes
static inline uint32_t xePowerI1Milli(uint32_t i1) {
	return (uint32_t)((uint64_t)(i1 & POWER_SETUP_I1_DATA_MASK) * 1000u >> POWER_SETUP_I1_SHIFT);
}

// The four power limits as xe_hwmon_get_preregistration_info reads them (xe_hwmon.c:1499-1508): PL1 and PL2 of the
// card (READ_PSYSGPU_POWER_LIMIT) and of the package (READ_PACKAGE_POWER_LIMIT). The read asks for READ_PL_FROM_FW, the
// param2 xe uses until it has written the limits back (prepare_power_limit_param2, xe_hwmon.c:178-188, with
// boot_power_limit_read false); this driver never writes them, so that stays the request. Plus I1 (power1_crit /
// curr1_crit). xe exposes no rated (TDP) value on these platforms (xe_hwmon.c:1124-1126 hides power_rated_max) and reads
// no PKG_POWER_SKU there, so there is none here either.
enum : uint32_t { XE_PL_CARD = 0, XE_PL_PKG = 1, XE_PL_CHANNELS = 2 };
struct XePowerLimits {
	int err {ENODATA};                    // 0, or the errno of the first failed limit read
	uint32_t word[XE_PL_CHANNELS][2] {};  // [card/package][PL1 = DATA0, PL2 = DATA1]
	int i1Err {ENODATA};
	uint32_t i1 {0};
};
// The report text: ", card PL1 X W (on|off), card PL2 ..., package PL1 ..., package PL2 ..." and, when I1 was read,
// ", card crit Z W" (or A). Units: XE_PWR_UNIT_MBX. Returns the length written (always < len; text that does not fit
// is cut).
static inline size_t xePowerLimitsText(char *buf, size_t len, const XePowerLimits &pl) {
	size_t n = 0;
	auto add = [&](int k) { if (k > 0) n = n + (size_t)k < len ? n + (size_t)k : (len ? len - 1 : 0); };
	if (!len) return 0;
	if (pl.err) {
		add(snprintf(buf, len, ", power limits unavailable (pcode error %d)", pl.err));
		return n;
	}
	static const char *const kCh[XE_PL_CHANNELS] = {"card", "package"};
	for (uint32_t c = 0; c < XE_PL_CHANNELS; c++)
		for (uint32_t l = 0; l < 2; l++) {
			const uint32_t w = pl.word[c][l], mw = xePowerLimitMw(w, XE_PWR_UNIT_MBX);
			const char *on = w & PWR_LIM_EN ? "on" : "off";
			if (mw % 1000)
				add(snprintf(buf + n, len - n, ", %s PL%u %u.%03u W (%s)", kCh[c], l + 1, mw / 1000, mw % 1000, on));
			else
				add(snprintf(buf + n, len - n, ", %s PL%u %u W (%s)", kCh[c], l + 1, mw / 1000, on));
		}
	if (!pl.i1Err) {
		const uint32_t m = xePowerI1Milli(pl.i1);
		add(snprintf(buf + n, len - n, ", card crit %u.%03u %s", m / 1000, m % 1000, pl.i1 & POWER_SETUP_I1_WATTS ? "W" : "A"));
	}
	return n;
}
