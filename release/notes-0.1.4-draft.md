<!-- DRAFT for 0.1.4 (9 Nov 2026, brought up to date with main on 10 Nov). Check before publishing: the package list
against package.sh's output, the upgrade steps against release/README-INSTALL.md's "Upgrading" section, that the B570
lines still say "untested", that the packaged IntelXe.kext is built from main after 10 Nov (platform layer, user
fences) and ran on the B580, and the Windows EFI tool's HybridPM / SSDT-ARCOFF lines once it has run on Windows. Also
(merges of 10 Nov after 03:00): that the packaged kext and plugin contain them (release.sh refuses packages older than
the last commit to their sources), the power fields of debug.intelxe.sensors read from the packaged kext, the WebGPU
deferredRendering sample re-run in Safari with the packaged plugin, and that the ASPM lines still say "untested".
(Merges of 10 Nov afternoon): the packaged libintelxevenc registers AV1 (vtencq --list), the Safari items re-checked with
the packaged plugin (three.js pages, shader cache "fc spec: HIT"), tools/regress --full on the packaged build. -->
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
- **Card and package power.** `sysctl debug.intelxe.sensors` now ends with the card's and the package's energy (J) and
  average power (W), read from the card's PMT telemetry the way Linux `xe_hwmon` reads it. On the test machine the
  registers gave 36.2 W for the card and 19.6 W for the package at idle, 40.4 W and 23.3 W under light load (read-only
  register reads, 10 November). The text before the new fields is unchanged. It also shows the card's and the
  package's power limits as the firmware set them, read through the GPU's pcode mailbox as Linux `xe_hwmon` does (on
  the test machine: card PL1 off, PL2 190 W, critical 380 W; package 155 W, off). For several minutes after a start the
  package's energy counter runs fast; the driver then shows `package power n/a` and keeps the card's power.
- **PCIe ASPM report and an L1 switch (experimental, not yet run on a B580).** `sysctl debug.intelxe.aspm` shows the
  power-saving state (ASPM) of every PCIe link between the GPU and the CPU's root port, and whether L1 passes Linux's
  checks. `sudo sysctl debug.intelxe.aspm_l1=1` turns L1 on for those links only if every link passes, `0` turns ASPM
  off, `-1` (the default) leaves them as the firmware set them. Nothing changes unless you write it, and a change lasts
  until the next restart. It is meant to lower the idle power above; whether it does is not measured yet.
- **Safari's WebGPU and Metal driver.** three.js's WebGPU renderer draws (r170 and r181 test pages: materials,
  environment maps, instancing, compute, shadows); its output pass read a uniform through a pointer kept in an argument
  buffer, which the translator turned into zero. WebGPU render bundles that WebKit validates on the GPU now work: a
  shader that encodes draws into an indirect command buffer (`render_command`, WebKit's `vsICB`) is translated, and the
  draws run from per-slot records with `vkCmdDraw*Indirect` (records in VRAM; consecutive slots with the same state
  are one multi-draw: about 0.03 µs of GPU time per slot, as direct draws, down from 11 µs). WGSL compute shaders with a `var<workgroup>` failed
  `createComputePipeline` in Safari: WebKit zeroes workgroup memory one byte at a time through a byte pointer into
  each 32-bit word, which Vulkan cannot express; the translator now writes each byte as a read-modify-write of its
  word (and a Metal `threadgroup` struct parameter zeroed whole, `s = S{}`, was refused for a related reason). Metal's GPU timestamps (counter sampling at stage
  boundaries, in nanoseconds) are new for applications; Safari does not offer WebGPU's `timestamp-query` on Intel GPUs
  (WebKit's choice, see Known issues).
- **nullmoth 2.9 merged.** Of upstream's 153 commits between 2.7.2 and 2.9 that touch the Metal driver and the
  translator, 42 are in (28 whole, 14 in part); DLSS, NVENC, application profiles, hybrid laptops and upstream's opt-in
  features are left out (`nullmoth/CHANGES.md` says why for each). New with it: LOD queries on every texture shape and
  pull-model interpolation (both answered from the device), shader-cache entries that prove they are whole (a torn
  file is translated again), lazily filled large heaps, drawing BGRA into an RGBA pipeline as Metal does, copies
  between size-compatible formats, nested argument encoders, command buffers that fail cleanly after the GPU is lost
  for good, and `nvmtl-air-dis` for developers. Metal 4 entry points stay off unless `NVMTL_METAL4=1`.
- **Safari keeps its compiled shaders.** WebKit's GPU process may not `fsync`, so every store of the Metal driver's
  shader caches failed there and Safari compiled its interface shaders again at every start (about 2 s each). The caches
  now write as that sandbox allows; the second start takes them from the cache.
- **AV1 encoding on by default.** The AV1 encoder is registered with VideoToolbox next to HEVC and H.264. `vtencq`
  measures encode quality against the source (PSNR): on the B580 H.264 43.3 dB at 8 Mbit/s, HEVC 43.7 dB at 8 Mbit/s,
  AV1 42.3 dB at 6 Mbit/s (10-bit 41.6 dB), every frame out.
- **IntelXe Manager, redesigned:** an Overview page with a status header and the one action that matters now; a
  **setup assistant** (prepare OpenCore, with Safari's settings in the same step if you want them; the driver; the EFI
  kext; a GPU test; done), which lists the EFI partitions to choose from when OpenCore recorded none and sets up Safari
  on the GPU and Zink from its last page; GPU tests (Metal features, OpenGL, OpenCL, video decoding bit for bit, encoding
  quality, compute rate, bandwidth, smoothness) and a long test; a Monitor page with five-minute charts of the GPU clock,
  temperature and frames, and an optional menu bar item; a Power and app page; start-up warnings with fixes; an
  install that shows its steps; an About window.
- **Signed releases.** From 0.1.4 on, a release's list of hashes (`.sha256`) is signed with the project's Ed25519 key
  (`.sha256.sig`, `release/signing.swift`). IntelXe Manager installs a package it downloaded only when that signature
  verifies with the key built into it and the zip's hash is in the list; a release that only came from the same
  GitHub page is refused. To check by hand: `swift release/signing.swift verify <key from app/Sources/Signing.swift>
  intel-gpu-macos-driver-0.1.4.sha256 intel-gpu-macos-driver-0.1.4.sha256.sig`.
- **Safari on the GPU from the app.** The Driver page's *Safari and WebKit* section installs, checks and removes the
  system-volume copy of the Metal driver and tells when a macOS update removed it; the EFI page sets OpenCore's
  `SecureBootModel` to `Disabled`, which that copy needs (backed up, undoable).
- **A check at login (optional):** one dialog only when something needs attention, such as a macOS update that removed
  the system-volume copy.
- **Native OpenGL apps through Zink, one at a time (experimental).** `cglzink-app.sh` in the Zink package makes
  `~/Applications/X (zink).app`, which starts a CGL/NSOpenGL application with its OpenGL on Zink: GZDoom (MAP01,
  uncapped) ~1910 fps against ~1600 on Apple's OpenGL.
  - **Every native OpenGL application at once (experimental, off by default):** `sudo ./install.sh --global-gl on`
    in the Zink package. A LaunchAgent puts the small `libcglzink-boot.dylib` into `DYLD_INSERT_LIBRARIES` of the login
    session (macOS passes it on because the driver's setup turns AMFI off), and in each process it decides once whether
    to load cglzink: application bundles only, not Apple's (Chess excepted), browsers, Electron/Chromium apps, video
    players or IntelXe Manager. `/Library/IntelXe/GL/cglzink-global.txt` refuses (`-bundle.id`) or allows
    (`+bundle.id`) one application. `sudo ./install.sh --global-gl off` turns it off, `--undo` turns it off first. On the
    B580 (11 Nov): Chess drew through zink; TextEdit, Calculator, System Settings, Safari and 1Password stayed on
    Apple's OpenGL; off restored Chess to Apple's OpenGL.
- **SSDT-ARCOFF adapts itself to your board.** When the card's ACPI path is not the shipped table's, `efi.sh`, the
  app and the Windows EFI tool write your path into a copy of the table (the same bytes from all three): no `.dsl` to
  edit, no `iasl`.
- **Reports that say what is wrong.** The diagnostics report starts with warnings and what to do about each, and the
  app's Report page creates it (as the user or in administrator mode), shows the step and the elapsed time while it
  runs, then what it found, and opens the issue form with the report ID filled in (about 16 s on the test machine). A
  new issue form, *Support for my Intel GPU*, asks for the Linux and macOS reports a new GPU needs; `--acpi` adds the
  DSDT/SSDT tables (never the ones that carry the Windows licence). macOS 26 no longer publishes those tables, so there
  the macOS report's `--acpi` collects nothing and the app greys the option out; the Linux report has them.
  `tools/clbench` times the same OpenCL kernels on Windows, macOS and Linux.

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
  have no B570 and have not run it.** The app's GPU test measures it against Intel's specification (11.52 TFLOP/s,
  380 GB/s), not against figures from a card. If you have one, please try it and open an issue with the diagnostics report
  (`tools/report/collect-macos.sh`), whether it works or not. Thanks to `@1964356263` for the device ID (PR #2).
- **HybridPM.kext for hybrid Intel CPUs (12th-14th gen, Alder Lake / Raptor Lake with E-cores).** macOS's CPU power
  management caps the P-cores of these CPUs and can hold busy cores at 800 MHz; the GPU driver does a lot of CPU work
  per command buffer, so the GPU looks slow too. On the test machine (i7-14700K) one CPU thread ran more than twice as
  fast and Geekbench's GPU scores were about a third higher. Optional, in the `-efi.zip` and the macOS package; the
  app's EFI page, `efi.sh` and the Windows EFI tool add it at stage 4 when the CPU needs it (desktop and laptop models,
  the U and P models included). It is a Lilu plugin (Lilu is not included); it leaves Core Ultra, CPUs without E-cores and older CPUs alone (it only logs why). `hpmstat` in the
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
   `IntelXeFB.kext`, `NMXAccel.kext` (its `Info.plist`: the B570's ID), the Metal driver and the video encoder (AV1 on
   by default) are new; Mesa and the video decoders are those of 0.1.3.
2. **Replace `IntelXe.kext` in the EFI** before you restart (the app's EFI page, `sudo ./efi.sh --apply` on macOS,
   `IntelXe-EFI.ps1` on Windows, or by hand; its `config.plist` entry stays as it is). It brings the B570's ID, the GPU
   clock, temperature and power readings, the settings the app's Power page writes, direct submission and the
   experimental ASPM switch.
3. **Hybrid Intel CPU (12th-14th gen with E-cores)?** The app's EFI page, `efi.sh` and `IntelXe-EFI.ps1` add
   `HybridPM.kext` in step 2, with its `Kernel > Add` entry **below `Lilu.kext`**. `IntelXe-EFI.ps1` goes by the CPU of
   the PC it runs on: run it on the PC that boots the EFI. HybridPM needs Lilu, which this release does not include:
   most EFIs already have it for VirtualSMC; otherwise take it from
   [acidanthera/Lilu](https://github.com/acidanthera/Lilu/releases), then run step 2 again. By hand, the guide's
   *Hybrid Intel CPUs* section has the entry and how to check it (`sysctl debug.hybridpm.why`).
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
- Run as root, the macOS report collected no `config.plist` from an EFI partition that OpenCore had left marked dirty at
  boot (macOS mounts such a partition read-write only, so the read-only mount failed); it now mounts it read-only with
  `mount_msdos` and unmounts it afterwards.
- An application that asked the Metal device for `supportsPlacementSparse` crashed (an unrecognized selector, an
  uncaught exception); it now gets NO. The device also answers the other properties the Metal driver had left out:
  `location` is Slot (was Unspecified), `maxTransferRate` comes from the root port's link (15753846152 B/s for the test
  machine's Gen4 x8 link; was 0), `supports32BitFloatFiltering` and `supports32BitMSAA` are YES as the Vulkan driver
  reports them, and `maxArgumentBufferSamplerCount` is the sampler heap's 2047. Checked on the B580 on 10 November, the
  new Metal driver loaded for the test process only; `mtl_f32filter` confirms the 32-bit float filtering (PASS).
- Texel reads (`read()`) of cube textures that a shader also samples returned wrong data: every texel was wrong (faces
  1-5 read 0, face 0 read face 4), cube arrays did not translate, and mip levels 1 and 2 read level 0. `mtl_cube_read`
  now passes every case on the B580 (float, integer and cube-array textures at levels 0-2, and a read-write cube; 10
  November, the new Metal driver loaded for the test process only).
- Safari's WebGPU: the deferredRendering sample failed with "Fragment function failed creation", and its G-buffer reads
  returned zero. WebKit's shader compiler reads a texture from an argument buffer as a 64-bit resource ID, which the
  translator did not take as a texture. All 88 WebGPU shader libraries that Safari compiled on the B580 now translate
  (one failed before), and the sample draws in Safari on the B580 (10 November). A
  texture chosen by a branch or a select now reads the chosen texture (before, another bound texture or zero); none of
  the captured shaders does this, so that part is untested on the device.

### For developers

- When the GuC resets a context or a job never starts, `IntelXe.kext` writes the fault registers, each render/compute
  engine's ring state and the queues with pending work to its G2H log, to tell a stuck engine from a GuC that does not
  schedule. It now also writes the BO moves in and out of the BAR window, the TLB invalidations (and whether one is
  in flight), and the faulting queue's VM: its last unbind, remap and bind, and whether the page tables changed after
  the queue's last invalidation.
- **Platform descriptors**, as Linux `xe_pci.c` has them (`kernel/IntelXe/xe_platform.*`): one entry per device-ID
  list with its IP versions, flags, engines, firmware names and what the driver still lacks for it. `IntelXe.kext` looks
  its platform up once at start and names it in the log (`IntelXe: 8086:e20b: BMG-G21, graphics 20.01, media 13.01,
  discrete`); only BMG-G21 (B580, B570) is supported, and the 17 other entries there (Gen12 to Panther Lake, and
  BMG-G31) are refused with one log line. XeProbe reads the same table. Apart from that line the B580 behaves as
  before. What each other family still needs: `docs/design/DESIGN-platforms.md`.
- **User fences** as `xe` has them: `DRM_XE_SYNC_TYPE_USER_FENCE` on exec and VM_BIND, and
  `DRM_IOCTL_XE_WAIT_USER_FENCE`, which Intel's compute runtime needs (they were refused before). A bind's user fence
  is written when the bind completes, also when that happens late. The `GEM_CREATE` extension chain is checked as
  `xe_bo.c` checks it. Mesa's Vulkan driver does not use user fences, so Metal, Vulkan and OpenGL are unaffected. The
  uAPI parity table (`docs/parity/`) now counts 99 of 182 xe uAPI items and 13 of 16 ioctls (was 77 and 11); the
  compute-runtime items left went from 35 to 24.
- `debug.intelxe.jobtime` (off by default): each job's stages in GPU timestamps. `debug.intelxe.sensors`: the GT clock,
  the package and VRAM temperatures and (see Highlights) the card and package energy and power, readable by anyone.
  `debug.intelxe.aspm` / `debug.intelxe.aspm_l1`: see Highlights; `kernel/README.md` has the checks and the order in
  which links are changed.
- The translator emits a relaxed threadgroup atomic (add, min, max, and, or, xor) as relaxed, so Mesa no longer
  fences shared local memory around each one (clbench `hist256`'s loop now matches IGC's code).
- Tests: `mtl_order_stress` (command buffer ordering across queues and threads), `direct_lat`, `mtl_lat split`,
  `ufence` (user fences on the GPU: every engine, wait ops, masks and timeouts, bind fences); host tests without a GPU
  for the platform table (`kernel/IntelXe/tests/platform_test.cpp`) and the uAPI argument checks
  (`kernel/IntelXe/tests/uapi_test.cpp`). The translator's unit and integration tests pass (one fix: a typed
  pointer with a malformed address space is refused instead of read as generic), and `xlate_check` translates an
  entry the way `newFunctionWithName:` does. New on 10 November: `mtl_cube_read` (every texel of every face, slice and
  level of cube textures), `mtl_props` (the device properties the Metal driver answers) and `mtl_f32filter` (linear
  filtering of 32-bit float textures), built by `nullmoth/build/build-intelxe.sh tests`; host tests `pmt_test` (the
  energy path: offsets, units, counter wraps, average power) and `aspm_test` (46 checks of the ASPM rules, the order of
  changes and the report).
- **One supported-device list:** `data/platforms.json` `"supported"` holds the cards the driver attaches to (B580,
  B570), and `tools/parity/devices.py` fails when any copy differs (the kexts' matches, `install.sh`, `efi.sh`, the app,
  the Windows EFI tool, the platform test, clbench); `release/release.sh` and `release/test-efi-flow.sh` run it. The
  app's GPU test takes its expected figures from that list by PCI device ID (another GPU gets no verdict, where any
  name with "Arc" used to get the B580's figures); the Power page's default range is built from the clock range the
  kernel reports ("Default (1200-2850 MHz)" on the B580). `clbench` and `cl_lat` choose the OpenCL GPU by vendor ID,
  and the encoder test path names its encoders after the card's model. `docs/design/DESIGN-platforms.md` section 4
  lists what a new family needs outside the kernel. `zink-gl/src/mesa-zink.diff`, the source record of the Zink
  binaries, now holds only what a Zink-only build compiles (it still carried ANV changes from before the IntelXe rename).
- Since the afternoon of 10 November: `mtl_timestamps` (counter sampling at every boundary, against the command
  buffer's GPU time), `mtl_gpu_icb` (draws a kernel and a vertex shader encode into an indirect command buffer; 6/6 on
  the B580 and on Apple's GPU), `mtl_icb_cost` (GPU time per indirect-command-buffer slot, against direct draws),
  `mtl_dirty_stress` (bindings across object destroys), `vtencq` (encode quality),
  the host test `pcode_test` (power-limit decoding). **`tools/regress`** runs the hardware checks on the test machine in
  one command (`regress.sh`, `--full` adds the WebGPU pages in Safari and Geekbench; the `sweep` page checks 18 WebGPU
  features the other pages do not reach) and ends in one table; its
  `selftest.sh` checks every verdict against recorded output. The kext publishes its platform start line as the
  `IntelXePlatform` registry property.
- Tools: `vcbench` crashed when run inside an HEVC set (it looked for an H.264 description); fixed, and `VCB_DUMP=<dir>`
  writes each picture for comparison. On the B580 (10 November) H.264 2K, HEVC 2K and HEVC 4K hardware pictures equal
  Apple's software decoder's for every frame; H.264 4K (a full-range stream) equals it in the decoder's own format,
  while asked for video range the hardware converts and Apple's software H.264 decoder does not. `dmode W H [Hz]`
  switches the display mode for good (it switched back when the process ended) and can pick the refresh rate.
- `release/release.sh` checks a release before it is published (version, tag, packages and their checksums, the
  versions inside, the notes, the identity scan) and publishes it only with `--publish`. It refuses packages built
  before the last commit to what goes into them (code, scripts, templates, the packager).

### Known issues

- **GPU faults after a long idle (cause open).** With the GuC low-latency hint on, the first heavy run after a long
  idle ended in a `MEMORY_CAT_ERROR`, a GT reset and a replayed WindowServer queue in 3 of 6 test runs, against 0 of 4
  without it. The hint is therefore off by default. The cause is not known yet; the new engine dump, which now also
  records the BO moves, TLB invalidations and the VM's last unbind before the fault, is there to find it. If you see
  it, please send a report.
- **Direct submission is off by default** until it has run unattended for longer (power, idle, sleep). It is a sysctl
  only, so it ends at the next restart.
- **Geekbench's Background Blur and Super Resolution** depend on the GPU clock: with the hint off they score lower
  than with it on.
- **The Windows EFI tool's new steps** (`HybridPM.kext`, SSDT-ARCOFF adapted to another port) are checked on macOS
  against `efi.sh`, byte for byte, but have not run on Windows yet, and the tool has not yet prepared an EFI that a PC
  then booted. Read each plan before you confirm it.
- **The B570 is untested**, as above.
- **PCIe ASPM (`debug.intelxe.aspm_l1`) has not run on a B580 yet.** Leave it at its default unless you are testing
  it; the report (`debug.intelxe.aspm`) only reads.
- **WebGPU `timestamp-query` is not offered in Safari** on Intel GPUs: WebKit checks the device name on x86_64
  (`HardwareCapabilities.mm`) and never asks the Metal driver. WebKit makes the same choice for every Intel GPU,
  Apple's own drivers included. three.js r187's Inspector (the FPS panel at the top right of most threejs.org WebGPU
  examples) turns timestamp tracking on after the renderer has checked for the feature, so those pages call
  `createQuerySet` without it and draw nothing in Safari on Intel GPUs; examples without the Inspector draw (11 Nov on
  the B580: 7 of 7 with it black, 3 of 3 without it and 8 of 8 WebGPU samples correct).
- **GPU-encoded indexed draws** must point into the index buffer the CPU encoded for that slot, with its primitive type
  (core Vulkan takes neither from GPU memory), and a slot the CPU encoded as an indexed draw takes only indexed draws
  from a shader; others are skipped and logged. WebKit's validation shader always meets these. In an indirect command
  buffer a shader can write, a slot whose state (pipeline, buffers, depth or raster state) differs from the slot
  before it still costs about 2 µs of GPU time (ANV reads each indirect parameter of a single draw with its own register
  load); runs of slots with the same state cost about 0.03 µs each.
- **Native OpenGL apps through Zink** (`cglzink-app.sh`) are experimental: no IOSurface drawing (browsers) or CGL
  pbuffers yet.
- **The switch for every OpenGL application** (`install.sh --global-gl on`) is experimental and off by default; it ran on
  the B580 with a few applications only. macOS names its LaunchAgent "IntelXeGL" in Login Items (a small helper that sets
  the variable only while both libraries are there). It inserts a library into every application the session starts: turn it off
  (`sudo ./install.sh --global-gl off`) before you delete `/Library/IntelXe/GL` by hand, because a missing inserted
  library stops every application from starting.
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
