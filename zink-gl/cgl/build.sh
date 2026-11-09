#!/bin/bash
# build.sh ARCH OUTDIR: libcglzink.dylib, the stand-in EGL and the test. ARCH is x86_64 for the B580 machine, arm64 for tests here.
set -euo pipefail
A=$1; O=$2; D=$(cd "$(dirname "$0")" && pwd); mkdir -p "$O"
/usr/bin/python3 -I "$D/../cgl-thunks/gen.py" "$O/gen" >/dev/null
cp "$D/../cgl-thunks/backend_names.h" "$O/gen/"
F="-arch $A -mmacosx-version-min=15.0 -O2 -w -I$O/gen"
clang $F -dynamiclib "$D/cglzink.m" -framework OpenGL -framework AppKit -framework QuartzCore -o "$O/libcglzink.dylib"
clang $F -dynamiclib "$D/fakeegl.c" -framework OpenGL -o "$O/libfakeegl.dylib"
clang $F "$D/layertest.m" -framework OpenGL -framework AppKit -o "$O/layertest"
