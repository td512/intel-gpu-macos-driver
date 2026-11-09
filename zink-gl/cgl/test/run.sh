#!/bin/bash
# SPDX-License-Identifier: MIT
# run.sh OUTDIR: layertest on Apple's GL, then through libcglzink with the stand-in EGL (fakeegl.c), then with the stand-in
# refusing what zink does not resolve. The pixel hashes (stdout) must be the same in all three; the layer's and the
# stand-in's reports go to stderr. No GPU of ours needed: this checks the layer's plumbing, not zink.
# LAYERTEST_VIEW=1 in the environment adds a view in a window that is never shown.
set -uo pipefail
O=${1:?usage: run.sh OUTDIR (from build.sh)}
cd "$O" || exit 1
./layertest > apple.txt 2> apple.err
CGLZINK_LOG=1 CGLZINK_EGL="$O/libfakeegl.dylib" DYLD_INSERT_LIBRARIES="$O/libcglzink.dylib" ./layertest > layer.txt 2> layer.err
CGLZINK_LOG=1 FAKEEGL_ZINK_NAMES=1 CGLZINK_EGL="$O/libfakeegl.dylib" DYLD_INSERT_LIBRARIES="$O/libcglzink.dylib" ./layertest > zinknames.txt 2> zinknames.err
CGLZINK_OFF=1 DYLD_INSERT_LIBRARIES="$O/libcglzink.dylib" ./layertest > off.txt 2> off.err
cat apple.txt
r=0
for f in layer zinknames off; do
    if cmp -s apple.txt $f.txt; then echo "$f: same as Apple's GL"; else echo "$f: DIFFERENT"; diff apple.txt $f.txt; r=1; fi
done
grep -h -E "^(layertest|fakeegl)|EGL [0-9]|used on two|swap interval|layer scale|stays|went|is gone" layer.err zinknames.err | sort | uniq -c
exit $r
