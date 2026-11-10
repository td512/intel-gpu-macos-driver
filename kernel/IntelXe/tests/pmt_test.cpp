// SPDX-License-Identifier: MIT
// pmt_test: offline check of the BMG energy path's pure parts (xe_pmt.h), no GPU needed.
//   1. the BAR0 offsets equal Linux regs/xe_pmt.h, regs/xe_regs.h and regs/xe_soc_remapper_regs.h
//   2. xe_guid_decode (xe_vsec.c:97-139) for every record/capability, and refusals of foreign GUIDs
//   3. the re-mapper rmw keeps the other bits; ENERGY_PKG / ENERGY_CARD field extraction
//   4. unit scaling (mul_u64_u32_shr(accum, SF_ENERGY, 14)) against 128-bit arithmetic
//   5. 32-bit wrap accumulation (xe_hwmon.c:534-535), the meter's power windows and the resync after suspend
//   6. the descriptor: BMG (G21 and G31) reads energy from PMT with unit shift 14; no other family reads energy
// c++ -std=c++17 -Wall -Wextra -I.. -o pmt_test pmt_test.cpp ../xe_platform.cpp && ./pmt_test
#include <stdio.h>
#include "xe_platform.h"
#include "xe_pmt.h"

static int fails, checks;
#define CHECK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); \
	printf("\n"); } } while (0)

// A GUID with the xe_vsec.c:73-78 layout
static uint32_t guid(uint32_t record, uint32_t cap, uint32_t device = BMG_PMT_GUID_DEVICE_ID, uint32_t low = 0) {
	return record << 30 | cap << 28 | (device & 0xffff) << 12 | (low & 0xfff);
}

int main() {
	// 1. offsets
	CHECK(PUNIT_TELEMETRY_GUID == 0x35b004, "PUNIT_TELEMETRY_GUID 0x%x", PUNIT_TELEMETRY_GUID);
	CHECK(BMG_DISCOVERY_OFFSET == 0x35b000, "BMG_DISCOVERY_OFFSET 0x%x", BMG_DISCOVERY_OFFSET);
	CHECK(BMG_TELEMETRY_OFFSET == 0x360000, "BMG_TELEMETRY_OFFSET 0x%x", BMG_TELEMETRY_OFFSET);
	CHECK(SG_REMAP_INDEX1 == 0x280008, "SG_REMAP_INDEX1 0x%x", SG_REMAP_INDEX1);
	CHECK(SG_REMAP_TELEM_MASK == 0xff000000u, "SG_REMAP_TELEM_MASK 0x%x", SG_REMAP_TELEM_MASK);
	CHECK(BMG_ENERGY_STATUS_PMT_OFFSET == 0x30, "energy offset");

	// 2. GUID decode
	uint32_t idx = 99, off = 99;
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_PUNIT, XE_PMT_CAP_TELEMETRY, BMG_PMT_GUID_DEVICE_ID, 0xabc), &idx, &off) == 0 &&
		idx == 0 && off == 0x200, "PUNIT telemetry: index %u offset 0x%x", idx, off);
	CHECK(xePmtTelemOffset(off, BMG_ENERGY_STATUS_PMT_OFFSET) == 0x360230, "energy word at BAR0 0x%x",
		xePmtTelemOffset(off, BMG_ENERGY_STATUS_PMT_OFFSET));
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_PUNIT, XE_PMT_CAP_WATCHER), &idx, &off) == 0 && idx == 0 && off == 0x14a0,
		"PUNIT watcher: index %u offset 0x%x", idx, off);
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_PUNIT, XE_PMT_CAP_CRASHLOG), &idx, &off) == 0 && idx == 2 && off == 0,
		"PUNIT crashlog: index %u offset 0x%x", idx, off);
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_OOBMSM_0, XE_PMT_CAP_CRASHLOG), &idx, &off) == 0 && idx == 4 && off == 0,
		"OOBMSM crashlog: index %u offset 0x%x", idx, off);
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_OOBMSM_0, XE_PMT_CAP_WATCHER), &idx, &off) == 0 && idx == 1 && off == 0x18d8,
		"OOBMSM_0 watcher: index %u offset 0x%x", idx, off);
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_OOBMSM_0, XE_PMT_CAP_TELEMETRY), &idx, &off) == 0 && idx == 1 && off == 0,
		"OOBMSM_0 telemetry: index %u offset 0x%x", idx, off);
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_OOBMSM_1, XE_PMT_CAP_TELEMETRY), &idx, &off) == 0 && idx == 1 && off == 0x1000,
		"OOBMSM_1 telemetry: index %u offset 0x%x", idx, off);
	CHECK(xePmtGuidDecode(guid(3, XE_PMT_CAP_TELEMETRY), &idx, &off) == -22, "record 3: -EINVAL");
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_PUNIT, 3), &idx, &off) == -22, "capability 3: -EINVAL");
	CHECK(xePmtGuidDecode(guid(XE_PMT_RECORD_PUNIT, XE_PMT_CAP_TELEMETRY, 0xe2f9), &idx, &off) == -19, "other device: -ENODEV");
	CHECK(xePmtGuidDecode(0xffffffffu, &idx, &off) == -19, "device gone (all ones): -ENODEV");
	CHECK(xePmtGuidDecode(0, &idx, &off) == -19, "zero GUID: -ENODEV");

	// 3. re-mapper and fields
	CHECK(xePmtRemapValue(0xabcdef12u, 0) == 0x00cdef12u, "remap index 0: 0x%08x", xePmtRemapValue(0xabcdef12u, 0));
	CHECK(xePmtRemapValue(0x00cdef12u, 4) == 0x04cdef12u, "remap index 4: 0x%08x", xePmtRemapValue(0x00cdef12u, 4));
	CHECK(xePmtEnergyPkg(0x1122334455667788ull) == 0x55667788u, "ENERGY_PKG is bits 31:0");
	CHECK(xePmtEnergyCard(0x1122334455667788ull) == 0x11223344u, "ENERGY_CARD is bits 63:32");

	// 4. scaling: 2^-14 J per count
	CHECK(xeEnergyMicrojoules(1ull << 14, 14) == 1000000, "one joule");
	CHECK(xeEnergyMicrojoules(1, 14) == 61, "one count = %llu uJ", (unsigned long long)xeEnergyMicrojoules(1, 14));
	CHECK(xeEnergyMicrojoules(3ull << 14 | 8192, 14) == 3500000, "3.5 J");
	uint64_t x = 0x9e3779b97f4a7c15ull;
	for (int i = 0; i < 1000; i++) {
		x ^= x << 13, x ^= x >> 7, x ^= x << 17;
		const uint64_t a = x >> 20;   // up to 2^44 counts (about a gigajoule): far beyond any uptime
		const uint64_t want = (uint64_t)((unsigned __int128)a * 1000000u >> 14);
		if (xeEnergyMicrojoules(a, 14) != want) {
			CHECK(false, "scaling of %llu: %llu, want %llu", (unsigned long long)a,
				(unsigned long long)xeEnergyMicrojoules(a, 14), (unsigned long long)want);
			break;
		}
	}
	checks++;

	// 5. accumulation
	XeEnergyAccum ea;
	ea.add(0x1000);
	CHECK(ea.accum == 0x1000, "the first read adds the counter itself (reg_val_prev 0)");
	ea.add(0xfffffff0u);
	ea.add(0x10);
	CHECK(ea.accum == 0x1000 + (0xfffffff0ull - 0x1000) + 0x20, "wrap: +0x20 across 2^32, accum 0x%llx",
		(unsigned long long)ea.accum);
	ea.add(0x10);
	CHECK(ea.accum == 0x100000010ull, "no change, no add");

	const uint64_t J = 1ull << 14, s = 1000000000ull, win = s / 2;
	auto word = [](uint64_t card, uint64_t pkg) { return (uint64_t)(uint32_t)card << 32 | (uint32_t)pkg; };
	XeEnergyMeter m;
	uint64_t card = 100 * J, pkg = 40 * J;
	m.update(word(card, pkg), 10 * s, win);
	CHECK(!m.havePower && m.uj(XE_ENERGY_CARD) == 100000000 && m.uj(XE_ENERGY_PKG) == 40000000, "first read: energy, no power");
	card += J / 50, pkg += J / 100;   // 1 ms later (sysctl's size call, then the text): no window yet
	m.update(word(card, pkg), 10 * s + s / 1000, win);
	CHECK(!m.havePower, "a window shorter than 0.5 s gives no power");
	card += 20 * J - J / 50, pkg += 12 * J - J / 100;   // 20 W card, 12 W package over the second
	m.update(word(card, pkg), 11 * s, win);
	CHECK(m.havePower && m.mw[XE_ENERGY_CARD] == 20000 && m.mw[XE_ENERGY_PKG] == 12000, "1 s: card %u mW, package %u mW",
		m.mw[XE_ENERGY_CARD], m.mw[XE_ENERGY_PKG]);
	card += J;   // a second reader 0.1 s later: same averages, window kept
	m.update(word(card, pkg), 11 * s + s / 10, win);
	CHECK(m.mw[XE_ENERGY_CARD] == 20000 && m.baseNs == 11 * s, "short read keeps the last average and the base");
	card += 17 * J;   // 18 J card since the base at 11 s; package idle
	m.update(word(card, pkg), 12 * s, win);
	CHECK(m.mw[XE_ENERGY_CARD] == 18000 && m.mw[XE_ENERGY_PKG] == 0, "18 J over the 1 s since the base: card %u mW",
		m.mw[XE_ENERGY_CARD]);
	// the counter wraps inside a window: 2^32 counts = 262144 J; 250 W for 2 s across the wrap
	card = 0x100000000ull - 3 * J;
	XeEnergyMeter w;
	w.update(word(card, pkg), 0, win);
	card += 500 * J;
	w.update(word(card, pkg), 2 * s, win);
	CHECK(w.mw[XE_ENERGY_CARD] == 250000, "wrap within the window: %u mW", w.mw[XE_ENERGY_CARD]);
	CHECK(w.uj(XE_ENERGY_CARD) == (0x100000000ull + 497 * J) * 1000000 >> 14, "sum continues past 2^32 counts");
	// suspend: the counter restarts lower; the sum must not jump by a wrap
	const uint64_t before = w.uj(XE_ENERGY_CARD);
	w.resync = true;
	w.update(word(5 * J, 2 * J), 100 * s, win);
	CHECK(w.uj(XE_ENERGY_CARD) == before && !w.havePower && !w.resync, "resync: sum kept (%llu uJ), no power",
		(unsigned long long)w.uj(XE_ENERGY_CARD));
	w.update(word(5 * J + 15 * J, 2 * J + 5 * J), 101 * s, win);
	CHECK(w.havePower && w.mw[XE_ENERGY_CARD] == 15000 && w.mw[XE_ENERGY_PKG] == 5000 &&
		w.uj(XE_ENERGY_CARD) == before + 15000000, "after resync: 15 W / 5 W, card %u mW", w.mw[XE_ENERGY_CARD]);

	// 6. descriptor
	const XePlatformDesc *g21 = xePlatformFind(0xe20b), *g31 = xePlatformFind(0xe221);
	CHECK(g21 && g21->energySource == XE_ENERGY_PMT && g21->energyShift == 14 && g21->hasSocRemapperTelem, "BMG-G21");
	CHECK(g31 && g31->energySource == XE_ENERGY_PMT && g31->energyShift == 14 && g31->hasSocRemapperTelem, "BMG-G31");
	for (uint32_t p = 0; p < kXePlatformCount; p++)
		if (kXePlatforms[p].platform != XE_BATTLEMAGE)
			CHECK(kXePlatforms[p].energySource == XE_ENERGY_NONE && !kXePlatforms[p].hasSocRemapperTelem,
				"%s: no energy source yet", kXePlatforms[p].name);

	printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
	return fails ? 1 : 0;
}
