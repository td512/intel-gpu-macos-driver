#!/bin/bash
# SPDX-License-Identifier: MIT
# build.sh ARCH OUTDIR: libcglzink.dylib, and for the tests the stand-in EGL and layertest (test/run.sh runs them).
# ARCH x86_64 for the B580 machine; arm64 for tests on an Apple silicon Mac. Builds on the build Mac (needs the SDK:
# gen/gen.py reads gliDispatch.h), not on the B580 machine.
set -euo pipefail
A=${1:?usage: build.sh x86_64|arm64 OUTDIR}; O=${2:?usage: build.sh ARCH OUTDIR}
D=$(cd "$(dirname "$0")" && pwd); mkdir -p "$O"
/usr/bin/python3 -I "$D/gen/gen.py" "$O/gen" >/dev/null
cp "$D/gen/backend_names.h" "$O/gen/"
F=(-arch "$A" -mmacosx-version-min=15.0 -O2 -Wall -Wno-deprecated-declarations -Wno-unused-function -I"$O/gen" -I"$D")
clang "${F[@]}" -dynamiclib "$D/cglzink.m" -framework OpenGL -framework AppKit -framework QuartzCore -framework IOSurface \
    -install_name /Library/IntelXe/GL/libcglzink.dylib -o "$O/libcglzink.dylib"
clang "${F[@]}" -w -dynamiclib "$D/test/fakeegl.c" -framework OpenGL -o "$O/libfakeegl.dylib"
clang "${F[@]}" -w "$D/test/layertest.m" -framework OpenGL -framework AppKit -framework QuartzCore -framework IOSurface -o "$O/layertest"
# ad-hoc signatures: the x86_64 linker does not sign by itself, and install.sh refuses unsigned libraries
for f in "$O/libcglzink.dylib" "$O/libfakeegl.dylib" "$O/layertest"; do codesign -s - -f "$f" 2>/dev/null; done
lipo -archs "$O/libcglzink.dylib"
