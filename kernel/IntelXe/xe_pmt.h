// SPDX-License-Identifier: MIT
// GPU energy from the PMT telemetry region, as Linux xe_hwmon reads it on Battlemage. The register layout comes from
// Linux drivers/gpu/drm/xe (tree abf8c33, v7.4 merge window): regs/xe_pmt.h, regs/xe_regs.h SOC_BASE,
// regs/xe_soc_remapper_regs.h, xe_vsec.c xe_guid_decode / xe_pmt_telem_read, xe_hwmon.c xe_hwmon_energy_get. Only the
// pure parts live here (offsets, GUID decode, field extraction, unit scaling, wrap accumulation, average power) so that
// tests/pmt_test.cpp builds them on the host; the MMIO reads are IntelXe::pmtTelemRead and IntelXe::energySample.
#pragma once
#include <stdint.h>

// regs/xe_regs.h:12
static constexpr uint32_t SOC_BASE = 0x280000;
// regs/xe_pmt.h:10-21. The discovery table (the VSEC telemetry header's .offset, xe_vsec.c:32) holds the PUNIT GUID;
// the telemetry window itself starts at BMG_TELEMETRY_OFFSET, both in BAR0 (tbir 0, xe_vsec.c:31).
static constexpr uint32_t BMG_PMT_BASE_OFFSET = 0xdb000;
static constexpr uint32_t BMG_DISCOVERY_OFFSET = SOC_BASE + BMG_PMT_BASE_OFFSET;
static constexpr uint32_t PUNIT_TELEMETRY_GUID = BMG_DISCOVERY_OFFSET + 0x4;
static constexpr uint32_t BMG_ENERGY_STATUS_PMT_OFFSET = 0x30;   // ENERGY_PKG 31:0, ENERGY_CARD 63:32
static constexpr uint32_t BMG_TELEMETRY_BASE_OFFSET = 0xe0000;
static constexpr uint32_t BMG_TELEMETRY_OFFSET = SOC_BASE + BMG_TELEMETRY_BASE_OFFSET;
// regs/xe_soc_remapper_regs.h:10-11: the SoC re-mapper picks which telemetry memory region the window shows
// (xe_soc_remapper.c:18-22 xe_soc_remapper_set_telem_region, an rmw of bits 31:24).
static constexpr uint32_t SG_REMAP_INDEX1 = SOC_BASE + 0x08;
static constexpr uint32_t SG_REMAP_TELEM_SHIFT = 24, SG_REMAP_TELEM_MASK = 0xffu << SG_REMAP_TELEM_SHIFT;

// xe_vsec.c:23 (a PMT GUID field, not a PCI id), 73-80 (GUID layout and the PUNIT telemetry offset), 82-93 (enums)
static constexpr uint32_t BMG_PMT_GUID_DEVICE_ID = 0xe2f8;
static constexpr uint32_t PUNIT_TELEMETRY_OFFSET = 0x0200, PUNIT_WATCHER_OFFSET = 0x14a0;
static constexpr uint32_t OOBMSM_0_WATCHER_OFFSET = 0x18d8, OOBMSM_1_TELEMETRY_OFFSET = 0x1000;
enum : uint32_t { XE_PMT_RECORD_PUNIT, XE_PMT_RECORD_OOBMSM_0, XE_PMT_RECORD_OOBMSM_1 };
enum : uint32_t { XE_PMT_CAP_CRASHLOG, XE_PMT_CAP_TELEMETRY, XE_PMT_CAP_WATCHER };

// xe_hwmon.c:84 ENERGY_UNIT: the energy unit of platforms whose power limits go through the pcode mailbox (BMG), as a
// right shift: one count is 2^-14 J (61 uJ). xe_hwmon_get_preregistration_info sets scl_shift_energy from it (:1527).
static constexpr uint8_t XE_ENERGY_UNIT_MBX = 14;

// xe_vsec.c:97-139 xe_guid_decode: the telemetry memory region (re-mapper index) and the offset inside the window that
// a GUID names. 0 or a negative errno-style value (-19 ENODEV: not a BMG GUID, -22 EINVAL: no such capability/record).
static inline int xePmtGuidDecode(uint32_t guid, uint32_t *index, uint32_t *offset) {
	const uint32_t recordId = guid >> 30 & 0x3, capType = guid >> 28 & 0x3, deviceId = guid >> 12 & 0xffff;
	if (deviceId != BMG_PMT_GUID_DEVICE_ID) return -19;
	if (capType > XE_PMT_CAP_WATCHER) return -22;
	*offset = 0;
	if (capType == XE_PMT_CAP_CRASHLOG) {
		*index = recordId == XE_PMT_RECORD_PUNIT ? 2 : 4;
		return 0;
	}
	switch (recordId) {
	case XE_PMT_RECORD_PUNIT:
		*index = 0;
		*offset = capType == XE_PMT_CAP_TELEMETRY ? PUNIT_TELEMETRY_OFFSET : PUNIT_WATCHER_OFFSET;
		break;
	case XE_PMT_RECORD_OOBMSM_0:
		*index = 1;
		if (capType == XE_PMT_CAP_WATCHER) *offset = OOBMSM_0_WATCHER_OFFSET;
		break;
	case XE_PMT_RECORD_OOBMSM_1:
		*index = 1;
		if (capType == XE_PMT_CAP_TELEMETRY) *offset = OOBMSM_1_TELEMETRY_OFFSET;
		break;
	default:
		return -22;
	}
	return 0;
}
// xe_vsec.c:147, 156: the BAR0 offset xe_pmt_telem_read copies from: the telemetry window, the GUID's offset in it, then
// the caller's offset (BMG_ENERGY_STATUS_PMT_OFFSET for energy).
static inline uint32_t xePmtTelemOffset(uint32_t guidOffset, uint32_t userOffset) {
	return BMG_TELEMETRY_OFFSET + guidOffset + userOffset;
}
// xe_soc_remapper.c:15, 20-21: SG_REMAP_INDEX1 with the telemetry field set to the region (xe_mmio_rmw32).
static inline uint32_t xePmtRemapValue(uint32_t old, uint32_t index) {
	return (old & ~SG_REMAP_TELEM_MASK) | (index << SG_REMAP_TELEM_SHIFT & SG_REMAP_TELEM_MASK);
}

// regs/xe_pmt.h:15-16 ENERGY_PKG / ENERGY_CARD of the 64-bit energy word (xe_hwmon.c:525-528 REG_FIELD_GET64).
static inline uint32_t xePmtEnergyPkg(uint64_t v) { return (uint32_t)v; }
static inline uint32_t xePmtEnergyCard(uint64_t v) { return (uint32_t)(v >> 32); }

// xe_hwmon.c:111-118 struct xe_hwmon_energy_info and :534-535: the 32-bit counter wraps (after 2^32 >> 14 J = 262144 J,
// about 22 minutes at 200 W), so each read adds the difference modulo 2^32 to a 64-bit sum. The first read adds the
// counter itself (reg_val_prev starts at 0), so the sum counts from the counter's own start, as Linux's does.
struct XeEnergyAccum {
	uint32_t prev {0};
	uint64_t accum {0};
	void add(uint32_t reg) {
		accum += (uint32_t)(reg - prev);
		prev = reg;
	}
};
// xe_hwmon.c:537-538 mul_u64_u32_shr(accum, SF_ENERGY, shift): microjoules, with the product split so that it cannot
// overflow 64 bits ((q << s + r) * 1e6 >> s = q * 1e6 + (r * 1e6 >> s) exactly).
static inline uint64_t xeEnergyMicrojoules(uint64_t accum, uint8_t shift) {
	const uint64_t q = accum >> shift, r = accum & ((1ull << shift) - 1);
	return q * 1000000ull + (r * 1000000ull >> shift);
}

// The two hwmon channels (xe_hwmon.c:45-46 CHANNEL_CARD, CHANNEL_PKG) plus an average power per channel. Linux leaves the
// power average to user space (energyN_input over time); debug.intelxe.sensors has no history of its own, so the meter
// keeps the energy and time of the last reading at least minWindowNs old and reports the average since then. Readers
// closer together than that (sysctl reads twice: size, then text; two apps polling) get the last average again rather
// than one over a few microseconds.
enum : uint32_t { XE_ENERGY_CARD = 0, XE_ENERGY_PKG = 1, XE_ENERGY_CHANNELS = 2 };
struct XeEnergyMeter {
	XeEnergyAccum ch[XE_ENERGY_CHANNELS];
	uint64_t baseUj[XE_ENERGY_CHANNELS] {}, baseNs {0};
	uint32_t mw[XE_ENERGY_CHANNELS] {};   // average power of the last full window, milliwatts
	bool haveBase {false}, havePower {false};
	bool resync {false};   // set at suspend: the counter may have restarted, so the next read only re-bases
	uint8_t shift {XE_ENERGY_UNIT_MBX};
	uint64_t uj(uint32_t c) const { return xeEnergyMicrojoules(ch[c].accum, shift); }
	void update(uint64_t pmtVal, uint64_t nowNs, uint64_t minWindowNs) {
		const uint32_t reg[XE_ENERGY_CHANNELS] = {xePmtEnergyCard(pmtVal), xePmtEnergyPkg(pmtVal)};
		if (resync) {
			// Sleep may have powered the card off and restarted the counters: a smaller value would read as a wrap of
			// 262144 J. Take the new values as the reference, keep the sum, and start a new power window.
			for (uint32_t c = 0; c < XE_ENERGY_CHANNELS; c++) ch[c].prev = reg[c];
			resync = haveBase = havePower = false;
		} else {
			for (uint32_t c = 0; c < XE_ENERGY_CHANNELS; c++) ch[c].add(reg[c]);
		}
		if (!haveBase || nowNs - baseNs >= minWindowNs) {
			if (haveBase) {
				const uint64_t dtUs = (nowNs - baseNs) / 1000 ? (nowNs - baseNs) / 1000 : 1;
				for (uint32_t c = 0; c < XE_ENERGY_CHANNELS; c++) {
					const uint64_t mwide = (uj(c) - baseUj[c]) * 1000 / dtUs;   // uJ / us = W; * 1000 = mW
					mw[c] = mwide > 0xffffffffull ? 0xffffffffu : (uint32_t)mwide;
				}
				havePower = true;
			}
			for (uint32_t c = 0; c < XE_ENERGY_CHANNELS; c++) baseUj[c] = uj(c);
			baseNs = nowNs;
			haveBase = true;
		}
	}
};
