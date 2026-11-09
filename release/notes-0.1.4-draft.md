<!-- DRAFT for 0.1.4 (9 Nov 2026). Check before publishing: the package list against package.sh's output, the upgrade
steps against release/README-INSTALL.md's "Upgrading" section, that the B570 lines still say "untested", and the
Windows EFI tool's HybridPM line (another branch adds it). -->
The faster-compute release: Metal and OpenCL work goes through the driver with less locking per command buffer, and a
translator fix doubles a matrix kernel's speed. Also: the **Arc B570**, a contributed device ID (untested by us),
**HybridPM** for 12th-14th gen hybrid Intel CPUs, and a redesigned **IntelXe Manager** with a setup assistant from a
fresh macOS install to a verified driver.

> [!WARNING]
> Experimental. Tested on one machine with one GPU (Arc B580); the Arc B570 is supported but untested. Unsigned; needs
> relaxed SIP/AMFI and OpenCore. Keep a USB stick with a working EFI before installing.

> [!NOTE]
> Developed with AI assistance: the code was written by Anthropic's Claude Opus 5.5 (High effort level) under the
> direction of the maintainer, who tests every build on the real hardware.

### Highlights

- **Faster Metal and OpenCL.** The Metal driver no longer holds one lock across a command buffer's submission and its
  completion (lock V2): back-to-back command buffers cost 11.1 us instead of 18.2, Geekbench 7 Metal 89.0k -> about
  95.5k, OpenCL about 81.7k -> 84-85k. On by default for applications; WindowServer and the system's interface keep the
  earlier path. `NVMTL_LOCK_V2=0` in an app's environment turns it off for that app.
- **A translator fix for indexed loads.** LLVM writes some additions as an `or` of bits that do not overlap, and Mesa
  vectorized only additions; the translator now turns such an `or` back into an add. clbench's register-blocked matrix
  multiply: 3778 -> 7130 GFLOP/s (Windows: 5456), checked against a CPU reference.
- **Apps see 8.2 GB of video memory to use, not 5.1** (`recommendedMaxWorkingSetSize`; `maxBufferLength` 4 GB).
- **Direct submission (opt-in, off by default).** While an application's queue submits often, it keeps a slot armed
  on its ring and the GPU starts the next job without a round trip through the GuC: a tiny job's exec -> signal 46-52 -> 15-17 us,
  Geekbench 7 Metal 97.2k and OpenCL 92.9k. Turn it on until the next restart with `sudo sysctl debug.intelxe.direct=1`.
- **IntelXe Manager, redesigned:** an Overview page with a status header and the one action that matters now; a
  **setup assistant** (prepare OpenCore, with Safari's settings in the same step if you want them; the driver; the EFI
  kext; a GPU test; done), which lists the EFI partitions to choose from when OpenCore recorded none and sets up Safari
  on the GPU and Zink from its last page; GPU tests (Metal features, OpenGL, OpenCL, video decoding bit for bit, encoding
  quality, compute rate, bandwidth, smoothness) and a long test; a Monitor page with five-minute charts of the GPU clock,
  temperature and frames, and an optional menu bar item; a Power and app page; start-up warnings with fixes; an
  install that shows its steps; an About window.
- **Safari on the GPU from the app.** The Driver page's *Safari and WebKit* section installs, checks and removes the
  system-volume copy of the Metal driver and tells when a macOS update removed it; the EFI page sets OpenCore's
  `SecureBootModel` to `Disabled`, which that copy needs (backed up, undoable).
- **A check at login (optional):** one dialog only when something needs attention, such as a macOS update that removed
  the system-volume copy.
- **Native OpenGL apps through Zink, one at a time (experimental).** `cglzink-app.sh` in the Zink package makes
  `~/Applications/X (zink).app`, which starts a CGL/NSOpenGL application with its OpenGL on Zink: GZDoom (MAP01,
  uncapped) ~1910 fps against ~1600 on Apple's OpenGL. There is no switch for every application.
- **SSDT-ARCOFF adapts itself to your board.** When the card's ACPI path is not the shipped table's, `efi.sh` and the
  app write your path into a copy of the table: no `.dsl` to edit, no `iasl`.
- **Reports that say what is wrong.** The diagnostics report starts with warnings and what to do about each, and the
  app's Report page creates it, shows what it found and opens the issue form with the report ID filled in. A new issue
  form, *Support for my Intel GPU*, asks for the Linux and macOS reports a new GPU needs; `--acpi` adds the DSDT/SSDT
  tables (never the ones that carry the Windows licence). `tools/clbench` times the same OpenCL kernels on Windows,
  macOS and Linux.

### Performance

The test machine (i7-14700K with HybridPM, Arc B580, macOS 26.7.1), 9 November 2026, GuC low-latency hint off in every
column. "0.1.3" is the 0.1.3 Metal driver measured the same day.

| | 0.1.3 | 0.1.4 | 0.1.4 + direct submission (opt-in) | Windows (Intel's driver) |
|---|---|---|---|---|
| Geekbench 7 Metal | 89.0k | 95.4k-95.7k | 97.2k | Vulkan 111.1k |
| Geekbench 7 OpenCL | ~81.7k | 84.1k-85.5k | 92.9k | 108.5k |
| clbench `sgemm_reg` | 3778 GFLOP/s | 7130 GFLOP/s | | 5456 GFLOP/s |
| Command buffers back to back | 18.2 us each | 11.1 us each | | |
| A tiny job, exec -> signalled | | 46-52 us | 15-17 us | |

With the GuC low-latency hint on, an earlier 0.1.4 test build (before lock V2) scored Geekbench 7 Metal 97.7k and
OpenCL 90.1k-92.5k: turning the hint off by default (Known issues) costs some speed; direct submission (opt-in) brings
OpenCL back to 92.9k.

Geekbench scores move a few percent between sessions (0.1.3's README quoted Metal 92.9k / OpenCL 86.9k from 5
November); compare the columns of one table, not numbers from different days.

### New hardware

- **Arc B570 (8086:E20C).** The kexts, `install.sh`, the app, `efi.sh` and the Windows EFI tool accept it, and About
  This Mac names it. It is the B580's chip (BMG-G21) with fewer Xe-cores, which the driver reads from the fuses. **We
  have no B570 and have not run it.** If you have one, please try it and open an issue with the diagnostics report
  (`tools/report/collect-macos.sh`), whether it works or not. Thanks to `@1964356263` for the device ID (PR #2).
- **HybridPM.kext for hybrid Intel CPUs (12th-14th gen, Alder Lake / Raptor Lake with E-cores).** macOS's CPU power
  management caps the P-cores of these CPUs and can hold busy cores at 800 MHz; the GPU driver does a lot of CPU work
  per command buffer, so the GPU looks slow too. On the test machine (i7-14700K) one CPU thread ran more than twice as
  fast and Geekbench's GPU scores were about a third higher. Optional, in the `-efi.zip` and the macOS package; the
  app's EFI page and `efi.sh` add it at stage 4 when the CPU needs it. It is a Lilu plugin (Lilu is not included); it leaves Core Ultra, CPUs without E-cores and older CPUs alone (it only logs why). `hpmstat` in the
  package shows per-core clocks and package power.

### Packages

| File | For | Unpack on |
|---|---|---|
| `IntelXe-Manager-0.1.4.zip` | the IntelXe Manager app (macOS 15 or later): setup assistant, install, the EFI, Safari, Zink, tests, reports | macOS |
| `intel-gpu-macos-driver-0.1.4-tahoe.zip` | macOS 26 Tahoe (tested on 26.7.1) | macOS |
| `intel-gpu-macos-driver-0.1.4-sequoia.zip` | macOS 15 Sequoia (same sources; not re-tested on Sequoia) | macOS |
| `intel-gpu-macos-driver-0.1.4-efi.zip` | the OpenCore pieces: `IntelXe.kext` (new), `SSDT-ARCOFF`, `HybridPM.kext` (new, optional), `IntelXe-EFI.ps1` for Windows | any system |
| `intel-gpu-macos-driver-0.1.4-zink-gl.zip` | optional: OpenGL through Mesa's Zink for LWJGL 3 games (Minecraft Java); new: `cglzink-app.sh` for native OpenGL apps (experimental) | macOS |

Checksums: `intel-gpu-macos-driver-0.1.4.sha256`. Install guide: `README-INSTALL.md` in each macOS package and
[in the repository](https://github.com/yusufklncc/intel-gpu-macos-driver/blob/v0.1.4/release/README-INSTALL.md)
(Turkish: `README-INSTALL.tr.md`).

### Upgrading from 0.1.3

1. Install the package (the app: *Download v0.1.4*, then *Install this package*; or `sudo ./install.sh --apply`).
   `IntelXeFB.kext`, `NMXAccel.kext` (its `Info.plist`: the B570's ID) and the Metal driver are new; Mesa and the
   video codecs are those of 0.1.3.
2. **Replace `IntelXe.kext` in the EFI** before you restart (the app's EFI page, `sudo ./efi.sh --apply` on macOS,
   `IntelXe-EFI.ps1` on Windows, or by hand; its `config.plist` entry stays as it is). It brings the B570's ID, the GPU
   clock and temperature readings, the settings the app's Power page writes and direct submission.
3. **Hybrid Intel CPU (12th-14th gen with E-cores)?** The app's EFI page and `efi.sh` add `HybridPM.kext` in step 2,
   with its `Kernel > Add` entry **below `Lilu.kext`**. HybridPM needs Lilu, which this release does not include: most
   EFIs already have it for VirtualSMC; otherwise take it from
   [acidanthera/Lilu](https://github.com/acidanthera/Lilu/releases), then run step 2 again. `IntelXe-EFI.ps1` does not
   add it yet; by hand, the guide's *Hybrid Intel CPUs* section has the entry and how to check it
   (`sysctl debug.hybridpm.why`).
4. If you installed the system-volume copy for Safari, install this package's too (the app's Driver page, *Safari and
   WebKit*; or `sudo ./system-volume/ssv-install.sh --apply`), so Safari gets the new Metal driver.
5. Restart.

The GuC low-latency hint that early 0.1.4 test builds turned on is opt-in: the app's *Power and app* page (*Fast GPU
response for apps*) or `/Library/GPUBundles/NVMTLDriver.low-latency`. What it gives: see Performance; why it is off:
see Known issues.

From 0.1.2 or earlier, follow the guide's upgrade section first.

### Fixed

- The Windows report saw no resized BAR (WMI lists only memory below 4 GB) and said "no Resizable BAR" on every card
  that has it; it now reads the ranges Windows assigned. Its summary broke whenever something was not collected, and
  `dxdiag` never finished in time.
- The macOS report listed the Metal driver under its pre-0.1.2 name only, so it did not see the installed one.

### For developers

- When the GuC resets a context or a job never starts, `IntelXe.kext` writes the fault registers, each render/compute
  engine's ring state and the queues with pending work to its G2H log, to tell a stuck engine from a GuC that does not
  schedule.
- `debug.intelxe.jobtime` (off by default): each job's stages in GPU timestamps. `debug.intelxe.sensors`: the GT clock
  and the package and VRAM temperatures, readable by anyone.
- The translator emits a relaxed threadgroup atomic (add, min, max, and, or, xor) as relaxed, so Mesa no longer
  fences shared local memory around each one (clbench `hist256`'s loop now matches IGC's code).
- Tests: `mtl_order_stress` (command buffer ordering across queues and threads), `direct_lat`, `mtl_lat split`.

### Known issues

- **GPU faults after a long idle (cause open).** With the GuC low-latency hint on, the first heavy run after a long
  idle ended in a `MEMORY_CAT_ERROR`, a GT reset and a replayed WindowServer queue in 3 of 6 test runs, against 0 of 4
  without it. The hint is therefore off by default. The cause is not known yet; the new engine dump is there to find it.
  If you see it, please send a report.
- **Direct submission is off by default** until it has run unattended for longer (power, idle, sleep). It is a sysctl
  only, so it ends at the next restart.
- **Geekbench's Background Blur and Super Resolution** depend on the GPU clock: with the hint off they score lower
  than with it on.
- **The Windows EFI tool does not add HybridPM.kext yet**; on Windows, add it by hand.
- **The B570 is untested**, as above.
- **Native OpenGL apps through Zink** (`cglzink-app.sh`) are experimental and per application: no switch for every
  application, and no IOSurface drawing (browsers) or CGL pbuffers yet.
- At the login window and the lock screen macOS redraws the password field's cursor and its glass material for every
  frame, about 140 frames a second on a 180 Hz monitor. It is macOS's own animation; it costs GPU time only while that
  screen is up (run benchmarks logged in).
- The rest as in 0.1.3: one monitor on DisplayPort; HiDPI sizes for monitors other than 2560x1440 untested; a held boot
  stays at the Apple logo (Reset NVRAM in the OpenCore picker).

### Credits

- `@1964356263` for the Arc B570 device ID (PR #2).
- [Lilu](https://github.com/acidanthera/Lilu) (acidanthera), which HybridPM builds on (BSD-3-Clause; its notice is in
  the kext and in `LICENSES/`).
- As in every release: nullmoth (NullMoth Systems), metal2vulkan (Anees Iqbal), Linux `xe` and i915, Mesa, FFmpeg and
  Emil J. Tywoniak's Xe2 VDEnc work; see the README.
