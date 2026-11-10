# VideoToolbox codecs on the B580

VideoToolbox decoder and encoder plug-ins that run on the B580's media engines through Vulkan Video (Mesa ANV from
`/Library/GPUBundles/nvmtl/`), with libavcodec doing the bitstream and reference bookkeeping. FFmpeg 9.0.2 with the
patches in `ffmpeg/` (Vulkan decode and encode fixes) is used as shared libraries next to the plug-ins.

- **Decoders** (`intelxeav1.c`, `libintelxeav1dec.dylib`; the file name is historical): AV1 (`av01`) and VP9, and H.264
  (High and below, 8-bit) and HEVC (Main, Main10) as the hardware decoder of last resort when the system has none for
  them; NV12/P010 IOSurface pixel buffers, full or video range as the stream is ('420f'/'xf20' or '420v'/'x420').
- **Encoders** (`encoder/intelxevenc.c`, `libintelxevenc.dylib`): HEVC (Main, Main10), H.264 (High) and AV1 (Main) on VDEnc,
  with libavcodec's `hevc_vulkan`, `h264_vulkan` and `av1_vulkan` (H.264 and AV1 encode on Xe2 need `mesa/patches/0010`,
  `0012`, `0015`).

**How they are registered (2026-10-29, the same on macOS 26):** macOS 15 and later drop third-party codec bundles in `/Library/Video/Plug-Ins` unless
they are Apple-signed, so the Metal plugin registers both libraries in-process (`VTRegisterVideoDecoderWithInfo` /
`VTRegisterVideoEncoderWithInfo`, plugin fix28) in every process that loads it, VTDecoderXPCService included. Installed
files: `/Library/GPUBundles/nvmtl/libintelxeav1dec.dylib`, `libintelxevenc.dylib`, `libavcodec.63.dylib`, `libavutil.61.dylib`.

## Files

| File | What |
|---|---|
| `intelxeav1.c`, `vtplugin.h` | the decoders (AV1, VP9, H.264, HEVC); the VideoToolbox decoder plug-in ABI (not in the public SDK: the CoreMedia derived-object layouts on macOS x86_64) |
| `build.sh` | builds `libintelxeav1dec.dylib` against the shared FFmpeg and copies `libavcodec.63`/`libavutil.61` next to it, all ad-hoc signed |
| `encoder/intelxevenc.c`, `encoder/vtencplugin.h` | the encoders; the encoder plug-in ABI (checked against Apple's x86_64 encoders) |
| `encoder/build.sh`, `encoder/vtenctest.m` | builds `libintelxevenc.dylib`; `vtenctest` drives a `VTCompressionSession` the way OBS/HandBrake/ffmpeg do |
| `ffmpeg/apply-patches.sh`, `ffmpeg/*.patch` | our FFmpeg 9.0.2 patches and the eight of them the released libraries carry, in order (two files there are not applied: see the script) |
| `ffmpeg/configure-shared.sh` | the FFmpeg 9.0.2 configuration: shared, LGPL only, AV1/H.264/HEVC/VP9 decoders + Vulkan hwaccels, Vulkan encoders |
| `tests/vtdec.m`, `tests/vtq.m`, `tests/sbprobe.c` | decode through `VTDecompressionSession`; what VideoToolbox offers; what a sandboxed video service can reach |
| `tests/vtencq.m` | encode quality: deterministic test sources made in memory, encoded, decoded straight from the encoder's sample buffers, PSNR Y/U/V and bit rate per pattern ([below](#encode-quality-vtencq)) |
| `tests/vcbench.m` | decode throughput the way Video Codec Test measures it (parallel sessions, its pixel formats), and hardware vs software checksums; `VCB_DUMP=<dir>` writes each picture's visible planes for `cmp -l` |

## Building

```sh
videotoolbox/ffmpeg/apply-patches.sh <ffmpeg-9.0.2>          # the released set, in order
mkdir ffbuild && cd ffbuild && cp -R <mesa>/include vk-include  # relative paths: avcodec_configuration() names none
FFMPEG_SRC=<ffmpeg-9.0.2> MESA_INCLUDE=vk-include PREFIX=install ../videotoolbox/ffmpeg/configure-shared.sh && make -j8 && make install
FFMPEG_INSTALL=$PWD/install MESA_INCLUDE=<mesa>/include ../videotoolbox/build.sh
FFMPEG_INSTALL=$PWD/install MESA_INCLUDE=<mesa>/include ../videotoolbox/encoder/build.sh
```

## Encode quality (vtencq)

`tests/vtencq.m` checks an encoder objectively on any Mac, with frameworks only (no FFmpeg, no source files): four
sources made with integer arithmetic (the same pictures on every machine and architecture; the `source` column is
their checksum) - `gradient` (smooth moving ramps), `noise` (band-limited texture moving 3,1 px a frame plus temporal
grain), `text` (glyph-like dots typed and scrolled, screen content), `scroll` (fractal terrain, 0.75,2.5 px a frame with
sub-pixel motion) - are encoded, the encoder's CMSampleBuffers are decoded by VideoToolbox with the format description
the encoder made, and every picture is compared with its source. PSNR is computed as FFmpeg's psnr filter averages it
(from the mean squared error; `avg` weights Y:U:V 4:1:1; checked against `ffmpeg -lavfi psnr` on a `--dump` stream:
same to 0.01 dB). Decoders: `sw` (the default for H.264/HEVC, Apple's, independent of the encoder) or `hw`/`any`. macOS
has no AV1 software decoder in VideoToolbox (an `av01` session fails with -12906 on macOS 27.0.1 arm64), so AV1 goes
through the IntelXe AV1 decoder (`--metal` or `--declib`, `--decoder any`).

```sh
clang -arch x86_64 -mmacosx-version-min=15.0 -O2 -fobjc-arc videotoolbox/tests/vtencq.m -framework Foundation \
  -framework CoreMedia -framework CoreVideo -framework VideoToolbox -framework Metal -o vtencq && codesign -f -s - vtencq
./vtencq --metal --codec hevc                                   # IntelXe encoders and decoders through the installed plug-in
./vtencq --lib libintelxevenc.dylib --codec hevc --decoder sw   # a test encoder build, registered in-process
./vtencq --metal --codec av1 --bitrate 6000000                  # AV1: INTELXEVENC_CODECS gets av1 before registration
./vtencq --encoder system --codec h264                          # whatever VideoToolbox picks (Apple's encoders on a Mac)
```

Options: `--codec h264|hevc|av1`, `--bitrate N` (bit/s; 8 Mbit/s, AV1 6), `--cbr`, `--10bit`, `--frames N` (120 per
pattern), `--size WxH`, `--fps F` (30), `--decoder hw|sw|any`, `--patterns`, `--keyint N`, `--noreorder`, `--realtime`,
`--dump DIR` (elementary streams; `--dump-source` adds the raw sources), `--list`.

**Reference: Apple's hardware encoders** (M1 Pro, macOS 27.0.1, `--encoder system`, 1920x1080, 120 frames per
pattern at 30 fps, frame reordering on, Apple's software decoder; the x86_64 build under Rosetta gives the same
numbers and checksums). PSNR-Y / bit rate against the target:

| encoder, mode | gradient | noise | text | scroll | all: PSNR-Y, avg | all: rate |
|---|---|---|---|---|---|---|
| H.264 VBR 8 Mbit/s | 53.48 dB, -79.5% | 35.94, +67.7% | 45.42, -52.9% | 48.48, -51.5% | 41.22, 42.28 | -29.0% |
| H.264 CBR 8 Mbit/s | 53.10, -12.5% | 37.12, +44.0% | 45.67, -8.2% | 48.01, -12.3% | 42.18, 43.08 | +2.8% |
| HEVC VBR 8 Mbit/s | 53.67, -81.1% | 35.55, +26.4% | 49.64, -48.4% | 50.00, -65.4% | 41.19, 42.58 | -42.1% |
| HEVC CBR 8 Mbit/s | 53.17, -12.5% | 37.30, +30.7% | 45.59, -6.9% | 46.90, -12.5% | 42.24, 43.46 | -0.3% |
| HEVC VBR 6 Mbit/s | 53.45, -76.4% | 34.82, +41.9% | 49.09, -34.8% | 49.70, -57.6% | 40.49, 41.89 | -31.7% |
| HEVC Main10 VBR 8 Mbit/s | 61.69, -82.7% | 35.35, +17.7% | 49.64, -48.5% | 51.33, -73.0% | 41.10, 42.58 | -46.6% |

Apple's VBR stays far under the target where the content is easy (gradient, scroll, text: 48-54 dB already) and goes
over it on the noise pattern (temporal grain everywhere): on synthetic sources an under-shoot with a high PSNR is the
expected behaviour of a VBR encoder, not a rate control fault. Encode speed here was 165-185 fps (Apple's encoders,
frames copied from memory).

## Licensing: FFmpeg

- FFmpeg is LGPL-2.1-or-later. It is modified (`ffmpeg/apply-patches.sh` lists the patches) and linked dynamically:
  `libavcodec.63.dylib` and `libavutil.61.dylib` are separate files that can be replaced by the user's own build of the
  same version and configuration. Anyone who receives those binaries must also be offered the corresponding FFmpeg
  9.0.2 source, the patches and the configure line (`ffmpeg/configure-shared.sh`).
- The plug-ins' own code (`intelxeav1.c`, `vtplugin.h`, `encoder/`, scripts, tests) is MIT.
- Earlier prototypes linked a patched FFmpeg statically (in the development history, not in this repository); that is no longer the case.
