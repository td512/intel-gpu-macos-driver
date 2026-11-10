# tools/regress: hardware regression checks

`regress.sh` runs the same set of checks on the test machine after every driver change. It prints one table,
`stage | result | numbers`, and exits 0 when no stage failed (1 on a FAIL, 2 on a usage error). It runs **on the test
machine** (an Arc B580/B570 with the IntelXe stack installed), which has no developer tools. It uses only bash 3.2, perl,
awk, sysctl, kmutil, `/usr/bin/log`, ps, open, killall, screencapture and curl.

```sh
tools/regress/regress.sh                  # quick set, about 3 minutes
tools/regress/regress.sh --full           # + vcbench, Safari WebGPU pages, Geekbench 7 (roughly 15-25 minutes)
tools/regress/regress.sh --only vtdec,metal
tools/regress/regress.sh --full --skip gb # everything but Geekbench
tools/regress/regress.sh --list           # every stage and what it checks
tools/regress/selftest.sh                 # the parsers against sample outputs (any Mac, no GPU)
```

The full set takes longer than a remote shell should wait. Start it detached and read the summary when it has finished:

```sh
nohup tools/regress/regress.sh --full >/dev/null 2>&1 &
cat ~/b580/regress/latest/summary.txt     # written last; "overall: PASS|FAIL (...)"
```

## What it never does

It never reboots, never writes the EFI, `/Library` or the system volume, and never changes a sysctl or NVRAM. Every step
that talks to the driver runs inside a time box: a perl `alarm` wrapper that puts the command in its own process group,
sends TERM to that group at the limit and KILL 3 s later. Steps never wait without a limit. The only processes it ends
are its own page server and Safari. It quits Safari with `killall Safari`, because an AppleScript quit can block on a
prompt, and only when the WebGPU stage started Safari itself. If Safari is already open, that stage is skipped unless
you pass `--force`. Safari may reopen the test tabs at its next launch.

## Stages

| stage | group | PASS when |
|---|---|---|
| `kext` | quick | `kmutil showloaded` lists `IntelXe`. The numbers give the IntelXe, IntelXeFB, NMXAccel, NMXAGDC and HybridPM versions. A version other than the checkout's `VERSION` gives a WARN |
| `platform` | quick | this boot's log has the start line `IntelXe: 8086:xxxx: <platform>, graphics a.b, media c.d, discrete` |
| `sensors` | quick | the second of two `debug.intelxe.sensors` readings, taken 1.5 s apart, has a card power field between 5 and 400 W. A temperature outside 10..110 C gives a WARN |
| `ufence` | quick | `ufence` prints `N checks, 0 failed` |
| `metal` | quick | `mtl_smoke`: `PASS: 0 of N values wrong` |
| `cube_read` | quick | `mtl_cube_read`: `PASS: every cube texel read returned its own texel` |
| `props` | quick | `mtl_props` reports `location 1` and throws no exception |
| `f32filter` | quick | `mtl_f32filter`: three PASS lines (R32F, RG32F, RGBA32F) |
| `timestamps` | quick | `mtl_timestamps`: counter sampling at stage boundaries in nanoseconds, `PASS (0 failed)` |
| `gpu_icb` | quick | `mtl_gpu_icb`: draws a shader encodes into an indirect command buffer, six `PASS slot` lines |
| `vtdec_h264`, `vtdec_hevc` | quick | `vtdec <clip> 60 --md5` runs twice. Both runs use the hardware decoder, report 0 errors and give the same per-frame md5s. The numbers include a 12-digit digest of the set of md5s. With `--save-ref` that digest becomes the reference, and later runs must match it |
| `stats` | quick | the `debug.intelxe.stats` counters at the start and end of the run. A new GT reset, GuC context reset, watchdog ban, dead H2G channel, TLB timeout or WEDGED gives a FAIL. Other bans, page faults, leaked queues, FAST_REQUEST failures and failed BO moves give a WARN |
| `vcbench:<set>` | full | each Video Codec Test set. `vcbench` runs Apple's hardware decoder in its own output format, then Apple's software decoder asked for that same format, both with `VCB_PS=1 VCB_SUM=1`, decoding every sample once. Every picture's checksum must match. The numbers add 3 s of single-session hardware throughput |
| `webgpu:tri`, `webgpu:sample`, `webgpu:three` | full | Safari opens each page from `pages/`, served by `srv` on 127.0.0.1. The page posts its result block to `/log`. See [Pages](#pages) |
| `gb_metal`, `gb_opencl` | full | the Geekbench 7 CLI (`--gpu Metal` / `--gpu OpenCL`) prints a score. A score below the configured minimum gives a WARN, not a FAIL, because scores are noisy. The numbers give the score, the result URL, the time taken and the indexers' CPU use at the start |

The result is one of PASS, FAIL, WARN or SKIP. A SKIP means a missing input, or a guard that refused to run the stage,
and the numbers say which.

**Benchmark guard.** Geekbench refuses to run within 20 minutes of boot (`REGRESS_BOOT_GUARD_MIN`) unless you pass
`--force`, because Spotlight and media-analysis indexing after a boot cost about 5% of the score (85k against 90k).
Before each run the stage records the CPU use of `mediaanalysisd`, `mds`, `mds_stores` and `mdworker*`. It also marks
the result when nobody is logged in at the console, since the login window's redraw costs about 14%.

**Network.** `webgpu:three` loads three.js r170 from the jsDelivr CDN, and Geekbench uploads its result. Pass
`--no-net` to skip both. When the CDN cannot be reached, the three.js page reports SKIP rather than FAIL.

## Prerequisites on the test machine (not in the repository)

By default everything lives under `~/b580/regress` (`REGRESS_HOME`):

```
~/b580/regress/bin/      mtl_smoke mtl_cube_read mtl_props mtl_f32filter mtl_timestamps mtl_gpu_icb ufence vtdec vcbench srv   (x86_64)
~/b580/regress/clips/    h264.<ext>  hevc.<ext>    one short H.264 and one HEVC clip (only the first 60 frames are decoded)
~/b580/regress/ref/      vtdec_*.digest            written by --save-ref
~/b580/regress/regress.conf                        optional settings (bash VAR=value lines, read first)
/Applications/Geekbench 7.app                       Geekbench 7 (CLI: Contents/Resources/geekbench_avx2)
/Applications/Video Codec Test.app                  its Contents/Resources/<set> folders (0.<ext>..N-1.<ext>, desc.<ext>)
```

The machine has no compiler, so build the binaries on the build Mac and copy them over:

```sh
nullmoth/build/build-intelxe.sh tests        # mtl_smoke, mtl_cube_read, mtl_props, mtl_f32filter, mtl_timestamps, mtl_gpu_icb (and xlate_check)
clang -arch x86_64 -mmacosx-version-min=15.0 -O2 -I kernel/IntelXe/uapi -o ufence user/tests/kernel/ufence.c -framework IOKit
clang -arch x86_64 -mmacosx-version-min=15.0 -fobjc-arc -O1 -o vtdec videotoolbox/tests/vtdec.m -framework Foundation \
      -framework AVFoundation -framework VideoToolbox -framework CoreMedia -framework CoreVideo -framework Metal
clang -arch x86_64 -mmacosx-version-min=15.0 -fobjc-arc -O1 -o vcbench videotoolbox/tests/vcbench.m -framework Foundation \
      -framework VideoToolbox -framework CoreMedia -framework CoreVideo -framework Metal
clang -arch x86_64 -mmacosx-version-min=15.0 -O2 -Wall -o srv tools/regress/srv.c
```

Run it as the user logged in at the console (Safari needs that session). Copy `tools/regress/` itself (`regress.sh`, `pages/`) to the machine as well, for example as part of a checkout.
`regress.sh` finds `pages/` next to itself and the checkout's `VERSION` two folders up, if the file is there.

The test programs run with `NVMTL_ENABLE=1`, which passes the plugin's allow-list. `vtdec` also gets
`VT_INTELXE_METAL=1`.

## Settings

Set these in the environment or in `regress.conf`:

| variable | default | meaning |
|---|---|---|
| `REGRESS_HOME` | `~/b580/regress` | runs, `bin/`, `clips/`, `ref/`, `regress.conf` |
| `REGRESS_BIN` | `$REGRESS_HOME/bin` | the test binaries and `srv` |
| `REGRESS_CLIPS`, `REGRESS_H264`, `REGRESS_HEVC` | `$REGRESS_HOME/clips`, `h264.*`, `hevc.*` | the vtdec clips |
| `REGRESS_GB` | `/Applications/Geekbench 7.app/Contents/Resources/geekbench_avx2` | Geekbench CLI |
| `REGRESS_GB_DEVICE` | (none) | `--gpu-device-id`, when the B580 is not Geekbench's default device (`geekbench_avx2 --gpu-list`) |
| `REGRESS_GB_METAL_MIN`, `REGRESS_GB_OPENCL_MIN` | 0 (off) | below this score: WARN |
| `REGRESS_BOOT_GUARD_MIN` | 20 | minutes after boot before Geekbench runs |
| `REGRESS_VCT`, `REGRESS_VCT_SETS` | the app's Resources, every folder with a `desc.*` | Video Codec Test sets (names without spaces) |
| `REGRESS_PORT` | 8765 | first port tried for `srv` (the next free one of ten is used) |
| `REGRESS_WEBGPU_PAGES` | `tri sample three` | pages to open, from `pages/` |

## Output

Each run writes to `$REGRESS_HOME/<yyyymmdd-hhmmss>/`, and `$REGRESS_HOME/latest` points at the newest run. The folder
holds:

- `results.tsv`: one row per stage (stage, result, numbers)
- `summary.txt`: the table and the overall line
- `env.txt`: macOS version, boot age and options
- one log per stage: `kext.log`, `platform.log`, `vtdec_h264-1.log`, `vcb-<set>-hw.log`, `gb_metal.log`, and so on
- `stats-before.txt` and `stats-after.txt`
- `www/`: the pages as served, with `log.txt`; also copied to `webgpu.log`
- `webgpu-fail.jpg`: a screenshot taken when a page failed

## Pages

Each page is MIT-licensed and uses the helpers in `pages/common.js`. A page posts one block:

```
PAGE <name>
INFO ...
PASS <case>: ...
FAIL <case>: ...
SKIP <case>: ...
END
```

Uncaught errors, unhandled rejections and uncaptured WebGPU errors all count as FAIL. Each page also has a timer (45 s,
or 90 s for three.js) that reports a FAIL if the page never finishes.

- `tri.html`: raw WebGPU. One triangle drawn six ways (draw, drawIndexed uint16, drawIndexed uint32, each with buffers
  filled through `mappedAtCreation` and through `writeBuffer`), into an offscreen rgba8unorm texture and into a canvas
  texture. The centre and a corner pixel of each are read back. That makes 24 checks.
- `sample.html`: three.js' output-pass pattern without three.js. An rgba16float source is sampled at
  `fragCoord.xy / uniform size`, with sampler, texture and uniform at bindings 0, 1 and 2. There are six variants,
  including `textureSampleLevel`, `textureLoad` and uv-as-colour. Two pixels are read back from each, making 12 checks.
- `three.html`: three.js r170 `WebGPURenderer`, an unlit orange cube. It reads the centre and corner of a
  `RenderTarget` with `readRenderTargetPixelsAsync`, and the centre and edge of the renderer's internal rgba16float
  target behind the output pass with `copyTextureToBuffer`. PASS when the centre is the mesh colour (in linear or sRGB
  encoding) and the corner is the background. A fall-back to WebGL2 is a FAIL.

All three pages pass on the Apple GPU of an M1 Mac in headless Chrome (tri 24, sample 12, three 4 checks). They have
not yet run in Safari on the B580.
