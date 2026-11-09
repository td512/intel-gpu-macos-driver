# Platform descriptors and the road to other Intel GPU families

> Design note with its date (2026-11-10, branch `platform-layer`): it records the plan and the state of that day, not
> the current status. The current state is in the README and `docs/devices/b580.md`.

IntelXe.kext ports Linux `drivers/gpu/drm/xe` and drives one device family: Battlemage BMG-G21 (Arc B580 `8086:e20b`,
B570 `8086:e20c`). This note covers three things:

- the platform descriptor layer that now holds what is platform-specific;
- what still assumes BMG, Xe2 or a discrete card, and why it stays that way for now;
- what each other family still needs.

Linux references are to `dl/linux-xe` (torvalds/master as fetched for this repo). The DMC file names come from
`drivers/gpu/drm/i915/display/intel_dmc.c` on torvalds/master as read on 2026-11-10, because that file is not in `dl/`.

## 1. The descriptor layer

`kernel/IntelXe/xe_platform.h` and `xe_platform.cpp` model Linux `xe_pci.c`.

- There is one `XePlatformDesc` per device-id list in `xe_probe_ids.inc`, which mirrors pciids.h.
- Each entry is built like `xe_pci.c` builds its entries: a device desc per platform (`tgl_desc` … `ptl_desc`) folded
  with its graphics IP desc (`graphics_xelp`, `xehpg`, `xelpg`, `xe2`) and its media IP desc (`media_xem`, `xelpmp`).
- The table is `constexpr`, so the kext gets no static constructor.

| field | Linux source |
|---|---|
| `name`, `subplatform`, `platform`, `ids` | XeProbe family name; `xe_subplatform_desc`; `enum xe_platform`; pciids.h |
| `preGmdidGraphics/Media` | `pre_gmdid_graphics_ip` / `pre_gmdid_media_ip` (0 when the IP is read from GMD_ID) |
| `graphicsVerx100/mediaVerx100` | the pre-GMD_ID IP, or `tests/xe_pci.c` GMDID_CASE (BMG 20.01 / 13.01); 0 = unknown |
| `dmaMaskBits`, `vaBits`, `vmMaxLevel`, `maxGtPerTile` | `dma_mask_size`, `va_bits`, `vm_max_level`, `max_gt_per_tile` |
| `isDgfx`, `hasFlatCcs`, `hasLlc`, `hasDisplay`, `hasSriov`, `hasPxp`, … | `xe_device_desc` has_* flags, `needs_scratch`, `XE_VRAM_FLAGS_NEED64K` |
| `hasUsm`, `hasAsid`, `hasAccessCounter`, `hasRangeTlbInval`, … | `xe_graphics_desc` has_* flags of the graphics IP |
| `engineMask` | graphics `hw_engine_mask` together with media `hw_engine_mask` (`XE_HW_ENGINE_*` bits) |
| `wopcmBytes` | `xe_wopcm.c` `xe_wopcm_size` |
| `patEntries` | `xe_pat.c` `xe_pat_init_early` n_entries (BMG: 28, Wa_16023588340) |
| `mocsUcIndex` | `xe_mocs.c` `get_mocs_settings` uc_index |
| `gucFw`/`gucStem`/`gucMajor`/`gucMinor`, `hucFw`, `gscFw`, `dmcFw` | `XE_GUC/HUC/GSC_FIRMWARE_DEFS`; i915 `dmc_firmware_default` |
| `supported`, `missing` | this driver: whether it starts on the entry, and if not, what the family still lacks |

**Lookup.** `IntelXe::start` looks the descriptor up once, as `xe_pci_probe` does.

- The device id comes from config space. A card that does not answer yet (rb7u) is looked up by the PCI family's
  `device-id` property instead.
- Start stops with one log line in each of these cases: the id has no entry, the entry is not supported, or the
  entry names GuC/HuC files other than the built-in ones. `build.py` now emits `kGucFwName` and `kHucFwName` for the
  last check.
- On success `gXePlat` and `gXePlatId` are set, and start never clears them.
- `IOPCIMatch` is unchanged (`0xe20b8086 0xe20c8086`), so today only those two ids reach `start`.

**XeProbe.** XeProbe (`docs/PROBE-MODE.md`) reads the same table, through `xePlatformFind` and `xePlatformByName`. Its
private family table is gone.

### What reads the descriptor now

| value | where |
|---|---|
| `dmaMaskBits` | `DmaMap::map` (IODMACommand address bits), the `ggttMap` device-address limit, the `alloc` physical mask |
| `vaBits` | `QUERY_CONFIG_VA_BITS`, the `bindOpCheck` VM-size check, `xeScanoutPin` and `vmMadvise` uncanonicalize |
| `isDgfx` | `QUERY_CONFIG_FLAG_HAS_VRAM`; together with `hasUsm`, `gUsm` (the UM queues live in VRAM) |
| `graphics/mediaVerx100` | `QUERY_GT_LIST` `ip_ver_major/minor` of both GTs |
| `maxGtPerTile` | `gVideoWanted` (whether a standalone media GT exists) |
| `wopcmBytes` | `loadGuc` WOPCM layout |
| `patEntries` | `patCheck` (VM_BIND) and `vmMadvise` PAT limit |
| `mocsUcIndex` | GuC shim `GUC_MOCS_INDEX`, MEM_SET, MEM_COPY, XY_BLOCK_COPY MOCS fields |
| `engineMask` | the CCS fuse (`read_compute_fuses_from_reg`) and the VDBOX/VEBOX fuses (`read_media_fuses`) |
| `gucFw`, `hucFw` | the start check against the built-in images |

### Equivalence on BMG (how it was checked)

- `tests/platform_test.cpp` (host, no GPU) checks four things:
  - every id has exactly one entry;
  - only BMG-G21 is supported, and e20b/e20c are in that entry;
  - the BMG-G21 values equal the literals the code used before (each check names the old file:line);
  - XeProbe's old family table, copied into the test, gives the same values per id and per name.

  Result: 1437 checks, 0 failed.
- An object-code check (`~/hackintosh/work/plat/tools/fold.py`, not in the repo) builds `IntelXe.cpp` and `xe_core.cpp`
  with `gXePlat` folded to a constant that holds the BMG-G21 values, then compares each function's disassembly with
  the build before the change. Data references are compared by the string they load.
  - `xe_core.o`: all 220 functions are identical.
  - `IntelXe.o`: the only differences are `start` and `waitDeviceReady` (both intended) and an out-of-line copy of
    the unchanged `intelxeBootArg`.
- The build adds no compiler warnings: the same 22 as before, by file and message.
- The output of `tools/parity/uapi.py` is the same: the same 182 cells with the same statuses (only line numbers
  differ).

Intended differences on BMG:

- One added log line at start:

  ```
  IntelXe: 8086:e20b: BMG-G21, graphics 20.01, media 13.01, discrete
  ```
- `waitDeviceReady` waits for the id that start found rather than for e20b-or-e20c.

## 2. What still assumes BMG / Xe2 / discrete (left on purpose)

All of this sits behind `supported`, which only BMG-G21 has. Each item would need per-platform data that Linux holds in
a table or a version check. Guessing at those values would be worse than leaving the code explicit.

- **GT layout.**
  - `MEDIA_GT_GSI_OFFSET` (0x380000) is a single Linux constant for every standalone media GT; only *whether* one
    exists is per platform (`maxGtPerTile`).
  - Media register bases, the media GuC objects (`mAdsG` …) and the step 13–16 paths assume media 13.01.
- **Engines.**
  - Fixed RCS0/BCS0 bases and LRC sizes in `firstBatchSetupOnly` (Xe2 `xe_gt_lrc_size`: render 16 KB, compute 12 KB,
    copy 8 KB); `goldenRcsOff` and the other offsets in `IntelXe.h` follow from those sizes.
  - The VCS/VECS bases and the at-most-4-media-engines check.
  - BCS8 (in the mask) is not driven, as before.
- **LRC images.** `lrc.h` has only `xe2_rcs/xcs/bcs_offsets`, and only Xe2 has no indirect ring state. XeProbe carries
  gen12/dg2/mtl tables in `xe_probe_lrc.inc`; IntelXe does not use them yet.
- **PAT / MOCS tables.**
  - `programPatMocs` writes `xe2_pat_table` (28 entries), `xe2_pat_ats` and `xe2_pat_pta` (dGFX), plus `xe2_mocs_table`.
  - `kPatComp`, `kPatReserved` and `kPatCoherent` are masks of `xe2_pat_table`.
  - GGTT PTEs use `xelpg_ggtt_pte_flags` (PAT bits 52/53, graphics ≥ 12.70); PPGTT PTEs use the Xe2 PAT encoding.
- **Memory.**
  - BAR2 is mapped unconditionally, and `vramUsableEnd` reads `SG_TILE_ADDR_RANGE0` and the Xe2 flat-CCS base
    (`XE2_FLAT_CCS_BASE_RANGE_*`).
  - The DSM/GSM bases are VRAM addresses.
  - The UM queues are in VRAM.
  - `deviceWmb` is VF_CAP_REG.
  - Every BO is a VRAM run or system memory.
  - **There is no integrated memory path:** no stolen memory, no LMEM-less placement, and no flat CCS in system
    memory (LNL/PTL).
- **GGTT.** GSM is at BAR0 + 8 MB, and a 4 GiB GGTT is implied (Linux: `gsm_size = 8M` for graphics ≥ 12.55, otherwise
  `GMCH_CTRL GGMS`). The layout constants in `IntelXe.h` and `xe_vram.h` sit inside 4 GiB.
- **Forcewake.** The GT ack is `FORCEWAKE_ACK_GT_MTL`, which Linux uses for graphics ≥ 12.70 (otherwise
  `FORCEWAKE_ACK_GT`). The render domain is taken on the primary GT, and the media VDBOX/VEBOX domains in `mediaWake`.
- **Interrupts.** `irqInit`/`irqHandle` follow `dg1_irq_handler` (Linux: graphics ≥ 12.10; `xelp_irq_handler` below).
  The display interrupt goes to IntelXeFB.
- **USM.** The GuC UM queues (`guc_um_init_params`) are set up on the primary GT only. Linux also sets them on the
  media GT.
- **SLPC.**
  - The minimum frequency is 1200 MHz: `BMG_MIN_FREQ`, Wa_14022085890, which Linux applies to BMG-G21 only
    (`xe_device_wa_oob.rules`). The value sits in `gSlpcMin`, `slpcParams` and `mediaPcStart`.
  - The NVRAM limits of IntelXe Manager are checked against 3000 MHz.
- **Workarounds.**
  - `firstBatchSetupOnly` applies the `gt_was`/`engine_was`/tunings that match graphics 20.01.
  - `loadGuc` sends the GuC WA KLVs for 20.01 and for media 13.01.
  - Also: Wa_16023588340 (L2 / CLOS3 / `l2Flush` XE2_GLOBAL_INVAL), Wa_16023105232 (PSMI), Wa_14021490052 (FF_MODE),
    Wa_14025883347 (media GuC reset), and `adjust_idledly`.
  - Every other family needs its own rule set from `xe_wa.c` / `xe_wa_oob.rules` / `xe_tuning.c`.
- **CCS mode.** `RCU_MODE` CCS enable, `CCS_MODE` in the engine-reset regset when there is more than one CCS, and all
  cslices on CCS0 (Xe_HPG and later, discrete).
- **Firmware.**
  - The GuC (70.72.1) and HuC (8.2.10, GSC CPD layout, authenticated through the GuC) are built in for BMG.
  - `QUERY_UC_FW_VERSION` reports the GuC submission version as 1.38.1.
  - No DMC is loaded: IntelXeFB keeps the pipe the GOP lit.
- **pcode, sensors, ReBAR.** `DGFX_PCODE_STATUS` waits at start, the BMG temperature/fan registers
  (`sensorsString`, step 1), Resizable BAR save/restore and `publishVram` (`VRAM,totalsize`) are all dGFX/BMG
  registers.
- **Names and matching.**
  - The `model` property is "B570" for e20c and "B580" otherwise. This needs a name per id before a second card.
  - The ids are in `build.py` IOPCIMatch.
- **IP version checks.** At runtime there are none: GMD_ID is only printed (step 1, step 13, `mediaGucLoad`). A GMD_ID
  check against `graphicsVerx100` at bring-up would be the natural next step. It was not added, because a read of GMD_ID
  at that moment has not been proved stable on the B580 (rb7u reads 0xffffffff early).
- **Display.** IntelXeFB (not part of this change) programs display 14.01 (BMG) registers.

## 3. What each family still needs

The table entries are complete for these families: IP versions, flags, engine mask, firmware names. What follows is
the code that does not exist yet. "Integrated memory path" means the following:

- BOs in system memory only (no VRAM, no BAR2);
- stolen memory (DSM) from `BDSM`, and GGTT size from `GMCH_CTRL`;
- coherent PAT indices for CPU-cached memory (`has_llc` on Gen12);
- on LNL/PTL, flat CCS backed by system memory;
- no `DGFX_PCODE_STATUS` wait, no ReBAR;
- `QUERY_MEM_REGIONS` without a VRAM region.

| family (ids) | IP (gfx / media) | firmware | display (DMC) | memory | other work |
|---|---|---|---|---|---|
| TGL, RKL, ADL-S/RPL-S, ADL-P/RPL-P/RPL-U, ADL-N | 12.00 / 12.00, no media GT | `i915/tgl_guc_70.bin` (ADL-P/RPL: `adlp_guc_70.bin`) 70.44; HuC `i915/tgl_huc.bin` (none on ADL-N), legacy (non-GSC) layout | 12 / 13: `tgl_dmc_ver2_12`, `rkl_dmc_ver2_03`, `adls_dmc_ver2_01`, `adlp_dmc` | integrated path; dma 39 bits; `has_llc` | Gen12 LRC images and register lists; xelp PAT (4) / gen12 MOCS (uc 3); `FORCEWAKE_ACK_GT`; `xelp_irq_handler`; xelp GGTT PTE; 3-level PPGTT (`vm_max_level` 3); no CCS; Gen12 workarounds |
| DG1 | 12.10 / 12.00 | `i915/dg1_guc_70.bin` 70.44, `i915/dg1_huc.bin` | 12: `dg1_dmc_ver2_02` | the VRAM path, without flat CCS (`vramUsableEnd` reads Xe2 flat-CCS registers); dma 39 | Gen12 LRC; xelp PAT / dg1 MOCS (uc 1); `dg1_irq_handler` fits; 3-level PPGTT; no CCS |
| DG2 (A770/A750/A580/A380/A310…), ATS-M | 12.55 / 12.55, no media GT | `i915/dg2_guc_70.bin` 70.53; no HuC in xe | 13: `dg2_dmc_ver2_08` (ATS-M: no display) | the VRAM path with 64K VRAM pages (`NEED64K`, GGTT 64K flag); flat CCS through the pre-Xe2 base registers | XeHP LRC images (`xp_dg2_*` in `xe_probe_lrc.inc`); xelp PAT (4) with xehp ops / dg2 MOCS (uc 1); `FORCEWAKE_ACK_GT`; xelp GGTT PTE; 3-level PPGTT; DG2 workarounds per G10/G11/G12 and stepping (needs the subplatform split of `kIdsDG2`); media on the primary GT |
| MTL, ARL | 12.70–12.74 / 13.00 (media GT) | `i915/mtl_guc_70.bin` 70.53; HuC `i915/mtl_huc_gsc.bin` through the GSC (`i915/mtl_gsc_102.bin`) | 14.00: `mtl_dmc` | integrated path; dma 46 | xelpg PAT (5) / MTL MOCS (uc 9); MTL LRC; GSC proxy; one CCS; 3-level PPGTT; MTL workarounds |
| LNL | 20.04 / 20.00 (media GT) | `xe/lnl_guc_70.bin` 70.53, `xe/lnl_huc.bin`, `xe/lnl_gsc_104.bin` | 20.00: `xe2lpd_dmc` | integrated path with flat CCS in system memory; `needs_scratch` | closest to BMG: Xe2 LRC, Xe2 PAT but 32 entries (no Wa_16023588340), the same MOCS; Xe2_LPG / Xe2_LPM workarounds; media 20.00 KLVs; GSC |
| BMG-G31 (e220–e223) | 20.01 (GMD_ID) | the same BMG firmware | 14.01: `bmg_dmc` | the same dGFX path | not tested; Wa_14022085890 (SLPC min 1200 MHz) is G21-only in Linux and must become conditional; then IOPCIMatch |
| PTL, WCL | 30.00 (WCL: from GMD_ID) / 30.00 (media GT) | `xe/ptl_guc_70.bin` 70.54, `xe/ptl_huc.bin`, `xe/ptl_gsc_105.bin` | 30.00: `xe3lpd_dmc`; WCL 30.02: `xe3lpd_3002_dmc` | integrated path with flat CCS in system memory | Xe3 PAT (32, compressed WB 16) and LRC; Xe3 workarounds; GSC |

Other G21 cards (B50/B60 Pro: e211, e212, …) share the supported G21 entry. They need only an IOPCIMatch id and a
`model` name, and then a test on the card.

### Order of work for a new family

1. Run XeProbe on it (`xeprobe=0xDEVICE`, `docs/PROBE-MODE.md`): identity, forcewake, GuC load, a store per engine.
2. Fill in what the entry is missing and mark it `supported`, then add the id to IOPCIMatch.
3. Replace each item of section 2 that the family hits with a descriptor field or a version check modelled on Linux.
   Examples: PAT and MOCS tables keyed by `platform`, LRC offsets by `graphicsVerx100`, the forcewake ack by
   `graphicsVerx100 >= 1270`, the IRQ handler by `>= 1210`, and an integrated memory path selected by `isDgfx`.
4. Bring its workaround rules over from `xe_wa_oob.rules` / `xe_wa.c`.
5. Extend `tests/platform_test.cpp` with that family's expected values.
