#!/bin/bash
# SPDX-License-Identifier: MIT
# selftest.sh: regress.sh's parsers, verdicts, table and time box against sample outputs written in the formats of the
# tools they read (no GPU, no driver needed: run it on the build Mac after changing regress.sh).
#   tools/regress/selftest.sh        exit 0 when every case gives the expected result
REGRESS_LIB=1 . "$(cd "$(dirname "$0")" && pwd)/regress.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/regress-selftest.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
n=0; bad=0

# expect NAME WANT "RESULT<TAB>numbers" [SUBSTRING]: the result is WANT (and the numbers contain SUBSTRING)
expect() {
	local got=${3%%"$TAB"*} nums=${3#*"$TAB"}
	n=$((n + 1))
	if [ "$got" = "$2" ] && { [ -z "${4:-}" ] || [[ "$nums" == *"$4"* ]]; }; then printf 'ok    %-26s %s %s\n' "$1" "$got" "$nums"
	else printf 'BAD   %-26s want %s%s, got: %s | %s\n' "$1" "$2" "${4:+ with \"$4\"}" "$got" "$nums"; bad=$((bad + 1)); fi
}
w() { cat >"$T/$1"; }   # w NAME <<EOF: a sample file

# ── kext (kmutil showloaded) ───────────────────────────────────────────────────────────────────────────────────────────
w kmutil <<'EOF'
No variant specified, falling back to release
Index Refs Address            Size       Wired      Name (Version) UUID <Linked Against>
    1  180 0                  0          0          com.apple.kpi.bsd (25.0.0) 00000000-0000-0000-0000-000000000001 <>
  201    1 0xffffff7f9a6b5000 0x2d4000   0x2d4000   io.github.yusufklncc.IntelXe (0.1.4) 00000000-0000-0000-0000-0000000000a1 <7 6 5 3 1>
  202    0 0xffffff7f9a989000 0x41000    0x41000    io.github.yusufklncc.IntelXeFB (0.1.4) 00000000-0000-0000-0000-0000000000a2 <201 7 6 5 3 1>
  203    0 0xffffff7f9a9ca000 0x9b000    0x9b000    com.nullmoth.NMXAccel (2.7.2) 00000000-0000-0000-0000-0000000000a3 <201 7 6 5 3 1>
EOF
expect kext "PASS" "$(check_kext "$T/kmutil" 0.1.4)" "IntelXe 0.1.4, IntelXeFB 0.1.4, NMXAccel 2.7.2"
expect kext-other-version "WARN" "$(check_kext "$T/kmutil" 0.1.5)" "checkout is 0.1.5"
grep -v 'IntelXe (' "$T/kmutil" >"$T/kmutil-no"
expect kext-not-loaded "FAIL" "$(check_kext "$T/kmutil-no" 0.1.4)" "not loaded"

# ── platform (log show --style compact) ────────────────────────────────────────────────────────────────────────────────
w log-ok <<'EOF'
Timestamp               Ty Process[PID:TID]
2026-11-10 09:12:01.104 Df kernel[0:1a2] IntelXe: 8086:e20b: BMG, graphics 20.01, media 30.00, discrete
EOF
w log-bad <<'EOF'
2026-11-10 09:12:01.104 Df kernel[0:1a2] IntelXe: 8086:e212 is BMG-G31: not supported yet (untested)
EOF
w log-none <<'EOF'
Timestamp               Ty Process[PID:TID]
EOF
expect platform "PASS" "$(check_platform "$T/log-ok")" "8086:e20b BMG"
expect platform-refused "FAIL" "$(check_platform "$T/log-bad")" "not supported yet"
expect platform-missing "FAIL" "$(check_platform "$T/log-none")" "no \"IntelXe: 8086:\""

# ── sensors (two sysctl -n readings: the value ends in a newline, sysctl adds one) ─────────────────────────────────────
w sensors <<'EOF'
act 0 MHz, req 400 MHz, RP0 2850 MHz, RPn 400 MHz, package 38 C, VRAM 46 C, card energy 9123.456 J, package energy 5011.002 J, card power n/a, package power n/a

act 0 MHz, req 400 MHz, RP0 2850 MHz, RPn 400 MHz, package 38 C, VRAM 46 C, card energy 9154.100 J, package energy 5029.390 J, card power 31.25 W, package power 18.40 W

EOF
expect sensors "PASS" "$(check_sensors "$T/sensors")" "card 31.25 W"
sed 's/card power 31.25 W/card power 812.00 W/' "$T/sensors" >"$T/sensors-hi"
expect sensors-implausible "FAIL" "$(check_sensors "$T/sensors-hi")" "out of 5..400"
sed 's/card power 31.25 W, package power 18.40 W/card power n\/a, package power n\/a/' "$T/sensors" >"$T/sensors-na"
expect sensors-no-power "FAIL" "$(check_sensors "$T/sensors-na")" "no card power"
printf 'unavailable (asleep)\n\n' >"$T/sensors-off"
expect sensors-unavailable "FAIL" "$(check_sensors "$T/sensors-off")" "unavailable"
sed 's/VRAM 46 C/VRAM 0 C/' "$T/sensors" >"$T/sensors-t0"
expect sensors-temp "WARN" "$(check_sensors "$T/sensors-t0")" "temperature"

# ── stats (debug.intelxe.stats, xeStatsString's format) ────────────────────────────────────────────────────────────────
stats_sample() {   # GT_RESETS GUC_RESETS BANS WATCHDOG PAGE_FAULTS WEDGED
	cat <<EOF
system sleep: suspends 0, resumes 0; last: 0 VRAM BOs saved (0 only through a scan-out pin), 0 MB, 0 without a backup, save copy 0; device resume 0, 0 restored, restore copy 0; scan-out pins now 2 (table full 0)
LRCs: 40 in VRAM, 0 in system memory (debug.intelxe.lrc_vram 1), VRAM asked but not had 0; last sleep: 0 saved, 0 without memory
video queues: multi-engine 2, single-engine 0 (vcs_single 0); user interrupts VCS0 120 VCS1 0 VCS2 0 VCS3 0
user fences: execs 12; binds written 4, faulted 0, bind fence late 0; waits 30: met 28, timed out 2, faulted 0, queue reset 1
irqs 99812 (GT 99000, display 812); G2H 4012 + media 22, FAST_REQUEST failures 0
waits: fallback wakeups 3, completed by the fallback (missed interrupt) 0; raced the wakeup 1, G2H read by the fallback 0; interrupt identities not valid 0
missed by wait: sync 0 clear 0 tlb 0 teardown 0 ring 0 submit 0 deps 0 kernel 0 surface 0 migrate 0
jobs: direct 0, via worker 5021, now waiting 0 in 0 queues; worker runs 5000; bans $3 (watchdog $4); same-queue in-fences skipped 0
direct submission (debug.intelxe.direct 0, idle 200 us): submits 0, arms 0; exits idle 0, contention 0, other 0; armed guc_id -1
TDR: checks 51, re-enabled 0, never started 0; GuC context resets $2; GT resets $1 (queues banned 0, replayed 0); H2G full 0, dead 0; page faults $5 (lost 0)$([ "$6" = 1 ] && echo "; WEDGED")
queues: live 14, freed 220, leaked 0; GGTT: system mappings 12, display ranges 3/64 (48 MB)
TLB invalidations 812 (ranged 700, done 812/0), timeouts 0, in-ring 33; deferred frees 10, pending 0; PT pages 300
VRAM end 0x2fc000000, used 812 MB (window 120 MB), free 200 + 10000 MB; clears 80; system BOs 30 MB
surface fences: attached 10, imported 4, ENOSPC 0, surfaces tracked 6
BO moves: into the window 3, out of it 2 (12 MB), failed 0, busy 0; eviction scans 1
window: refusals 0, page-table allocation failures 0; spills to system memory: window 0 (0 MB), VRAM 0; CPU maps made 10, gone 8 (debug.intelxe.vram); maps of BOs the full window could not take: 0 moved to system memory, 0 failed

EOF
}
stats_sample 0 0 0 0 0 0 | stats_counters >"$T/st-a"
stats_sample 0 0 0 0 0 0 | stats_counters >"$T/st-same"
stats_sample 1 2 2 1 0 0 | stats_counters >"$T/st-reset"
stats_sample 0 0 1 0 3 0 | stats_counters >"$T/st-fault"
stats_sample 0 0 0 0 0 1 | stats_counters >"$T/st-wedged"
expect stats-counters "PASS" "PASS$TAB$(tr '\n' ' ' <"$T/st-reset")" "guc_resets 2 gt_resets 1 bans 2 watchdog_bans 1 page_faults 0 h2g_dead 0 tlb_timeouts 0 leaked 0 fast_req_fail 0 move_fails 0 uf_timeouts 2 wedged 0"
expect stats "PASS" "$(check_stats "$T/st-a" "$T/st-same")" "no new resets"
expect stats-reset "FAIL" "$(check_stats "$T/st-a" "$T/st-reset")" "gt_resets +1, guc_resets +2, watchdog_bans +1, bans +2"
expect stats-fault "WARN" "$(check_stats "$T/st-a" "$T/st-fault")" "bans +1, page_faults +3"
expect stats-wedged "FAIL" "$(check_stats "$T/st-a" "$T/st-wedged")" "wedged +1"
echo "no device" | stats_counters >"$T/st-none"
expect stats-unreadable "FAIL" "$(check_stats "$T/st-a" "$T/st-none")" "unreadable"

# ── ufence, mtl_smoke, mtl_cube_read, mtl_props, mtl_f32filter ─────────────────────────────────────────────────────────
w ufence <<'EOF'
1. argument errors
2. exec user fence on every engine
  rcs0 (gt 0): written, exec -> wait return 41.2 us
10. exec fence at an unmapped GPU address of a scratch VM
user fences: execs 140; binds written 4, faulted 0, bind fence late 0; waits 77: met 70, timed out 6, faulted 1, queue reset 1
96 checks, 0 failed
EOF
expect ufence "PASS" "$(check_ufence "$T/ufence" 0)" "96 checks, 0 failed"
sed 's/96 checks, 0 failed/96 checks, 2 failed/' "$T/ufence" >"$T/ufence-2"
expect ufence-failed "FAIL" "$(check_ufence "$T/ufence-2" 1)" "2 failed"
printf 'no IntelXe service\n' >"$T/ufence-none"
expect ufence-no-service "FAIL" "$(check_ufence "$T/ufence-none" 1)" "no summary"

w smoke <<'EOF'
NMXAccel registry id: 0x100000a2c
PASS: 0 of 65536 values wrong on Intel(R) Arc(TM) B580 Graphics (threadgroup 1024)
EOF
expect metal "PASS" "$(check_smoke "$T/smoke" 0)" "0 of 65536"
printf 'FAIL: no B580 Metal device among 0\n' >"$T/smoke-none"
expect metal-no-device "FAIL" "$(check_smoke "$T/smoke-none" 1)" "no B580 Metal device"

w cube <<'EOF'
device: Intel(R) Arc(TM) B580 Graphics (NVMTLDevice)
PASS cube float  level 0: 0 of 1536 texels wrong
PASS cube float  level 1: 0 of 384 texels wrong
PASS cube float  level 2: 0 of 96 texels wrong
PASS cube uint   level 0: 0 of 1536 texels wrong
PASS cube array  level 0: 0 of 3072 texels wrong
PASS cube rw     level 0: 0 of 1536 texels wrong
PASS: every cube texel read returned its own texel
EOF
expect cube_read "PASS" "$(check_cube "$T/cube" 0)" "6 cube level"
sed -e 's/^PASS cube uint   level 0: 0 of/FAIL cube uint   level 0: 12 of/' -e 's/^PASS: every.*/FAIL/' "$T/cube" >"$T/cube-bad"
expect cube_read-wrong "FAIL" "$(check_cube "$T/cube-bad" 4)" "FAIL cube uint"

w props <<'EOF'
name Intel(R) Arc(TM) B580 Graphics | class NVMTLDevice
registryID 0x100000a2c location 1 locationNumber 0 maxTransferRate 16000000000
peerGroupID 0 peerIndex 0 peerCount 1 lowPower 0 headless 0 removable 0 unified 0
32BitFloatFiltering 1 32BitMSAA 1 QueryTextureLOD 1 PullModel 1 PlacementSparse 0
maxArgumentBufferSamplerCount 2048 maxConcurrentCompilationTaskCount 4 sparseTileSize 65536 recommendedMaxWorkingSet 12348030976
buffer sparseBufferTier 0
texture sparseTextureTier 0
EOF
expect props "PASS" "$(check_props "$T/props" 0)" "location 1"
sed 's/location 1 /location 0 /' "$T/props" >"$T/props-loc"
expect props-location "FAIL" "$(check_props "$T/props-loc" 0)" "location 0"
head -4 "$T/props" >"$T/props-exc"
echo "*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[NVMTLDevice supportsPlacementSparse]: unrecognized selector'" >>"$T/props-exc"
expect props-exception "FAIL" "$(check_props "$T/props-exc" 134)" "NSInvalidArgumentException"

w f32 <<'EOF'
device Intel(R) Arc(TM) B580 Graphics supports32BitFloatFiltering 1
PASS R32Float: 0.0000 0.5000 1.0000 (want 0 0.5 1)
PASS RG32Float: 0.0000 0.5000 1.0000 (want 0 0.5 1)
PASS RGBA32Float: 0.0000 0.5000 1.0000 (want 0 0.5 1)
EOF
expect f32filter "PASS" "$(check_f32filter "$T/f32" 0)" "3/3"
sed 's/^PASS RG32Float: 0.0000 0.5000/FAIL RG32Float: 0.0000 0.0000/' "$T/f32" >"$T/f32-bad"
expect f32filter-wrong "FAIL" "$(check_f32filter "$T/f32-bad" 0)" "failed: RG32Float (exit 0)"

# ── vtdec --md5 (two runs) ─────────────────────────────────────────────────────────────────────────────────────────────
vt() {   # CODEC FRAMES SALT HW: a vtdec --md5 run whose md5s are made from the frame number (and SALT for one frame)
	printf "VTIsHardwareDecodeSupported('av01') = 1\nsession (%s, hardware required) -> 0, using hardware %s\n" "$1" "$4"
	local i; for i in $(seq 1 "$2"); do
		printf 'frame %d 1920x1080 fmt 420v Y[0]=16 md5 %s\n' "$i" "$(printf 'f%d%s' "$i" "$([ "$i" = 7 ] && echo "$3")" | perl -MDigest::MD5=md5_hex -e 'print md5_hex(<STDIN>)')"
	done
	printf '%d samples sent, %d frames out, 0 errors, 412.3 ms\n' "$2" "$2"
}
vt avc1 60 "" yes >"$T/vt1"; vt avc1 60 "" yes >"$T/vt2"; vt avc1 60 x yes >"$T/vt3"; vt avc1 60 "" no >"$T/vt-sw"
expect vtdec "PASS" "$(check_vtdec "$T/vt1" "$T/vt2" 0 0 "")" "avc1 60 frames"
expect vtdec-differ "FAIL" "$(check_vtdec "$T/vt1" "$T/vt3" 0 0 "")" "runs differ: 1 of 60"
expect vtdec-software "FAIL" "$(check_vtdec "$T/vt-sw" "$T/vt-sw" 0 0 "")" "not on the hardware"
vtdec_digest "$T/vt1" >"$T/ref-ok"; echo 000000000000 >"$T/ref-bad"
expect vtdec-reference "PASS" "$(check_vtdec "$T/vt1" "$T/vt2" 0 0 "$T/ref-ok")" "= reference"
expect vtdec-reference-differs "FAIL" "$(check_vtdec "$T/vt1" "$T/vt2" 0 0 "$T/ref-bad")" "reference 000000000000"
printf "session (hvc1, hardware required) -> -12906, using hardware no\n" >"$T/vt-fail"
expect vtdec-no-session "FAIL" "$(check_vtdec "$T/vt-fail" "$T/vt-fail" 1 1 "")" "exit 1/1"

# ── vcbench hardware vs software ───────────────────────────────────────────────────────────────────────────────────────
vcb() {   # HW FMT SALT: a VCB_SUM=1 run of 30 pictures (pts in display order, printed in decode order)
	printf 'metal Intel(R) Arc(TM) B580 Graphics\ncodec hvc1 3840x2160 atoms hvcC\nfrom parameter sets: 0\nhardware %s\n' "$1"
	local p; for p in 0 2 1 3 5 4 6 8 7 9 11 10 12 14 13 15 17 16 18 20 19 21 23 22 24 26 25 27 29 28; do
		printf 'frame pts %d fmt %s 3840x2160 sum %016x\n' "$((p * 1001))" "$2" "$(( (p * 2654435761 + ${3:-0}) & 0xffffffffffff ))"
	done
	printf 'one %s async 0: 30 frames in 0.41 s = 73 fps, errors 0, loops 1, wait per loop 2.00 ms, creates 1 (3.10 ms each)\n' "$2"
	printf 'TOTAL threads 1: 30 frames in 0.41 s = 73 fps, errors 0\n'
}
vcb 1 420f >"$T/vh"; vcb 0 420f >"$T/vs"; vcb 1 420v >"$T/vs-fmt"; vcb 0 420f 5 >"$T/vs-sum"; vcb 0 420f >"$T/vh-sw"
expect vcbench "PASS" "$(check_vcbench "$T/vh" "$T/vs" 0 0)" "30 pictures = software (420f)"
expect vcbench-format "FAIL" "$(check_vcbench "$T/vh" "$T/vs-fmt" 0 0)" "30 of 30 pictures differ"
expect vcbench-sums "FAIL" "$(check_vcbench "$T/vh" "$T/vs-sum" 0 0)" "first pts 0"
expect vcbench-not-hw "FAIL" "$(check_vcbench "$T/vh-sw" "$T/vs" 0 0)" "hardware decoder not used"
head -20 "$T/vs" >"$T/vs-short"
expect vcbench-missing "FAIL" "$(check_vcbench "$T/vh" "$T/vs-short" 0 0)" "missing"
expect vcb-fmt "PASS" "PASS$TAB$(vcb_fmt "$T/vh")/$(vcb_fps "$T/vh")" "420f/73"

# ── Geekbench 7 CLI ────────────────────────────────────────────────────────────────────────────────────────────────────
w gb <<'EOF'
background CPU at start: mds_stores 2%, mediaanalysisd 0%; console user: tester
Geekbench 7.0.0 Tryout : https://www.geekbench.com/

System Information
  Operating System              macOS 26.7.1

Metal Information
  Device Name                   Intel(R) Arc(TM) B580 Graphics

Metal
  Background Blur               8812         ...

Benchmark Summary
  GPU Score                     91280

Upload succeeded. Visit the following link and view your results online:

  https://browser.geekbench.com/v7/gpu/366752
EOF
expect gb "PASS" "$(check_gb "$T/gb" 0 80000)" "91280 https://browser.geekbench.com/v7/gpu/366752"
expect gb-low "WARN" "$(check_gb "$T/gb" 0 95000)" "91280 < 95000"
printf 'regress: timed out after 900 s\n' >"$T/gb-to"
expect gb-timeout "FAIL" "$(check_gb "$T/gb-to" 124 0)" "exit 124"

# ── WebGPU pages (srv's log.txt: the blocks the pages post) ───────────────────────────────────────────────────────────
w wg <<'EOF'
PAGE tri
INFO adapter: intel / xe-2lpg
PASS offscreen draw/mapped centre: got 255,128,0 want 255,128,0
PASS offscreen draw/mapped corner: got 51,102,153 want 51,102,153
END
PAGE sample
INFO adapter: intel
PASS const uv 0.25 (40,30): got 255,64,0 want 255,64,0
FAIL fragCoord/uniform (120,90): got 255,64,0 want 8,33,82 (tolerance 2)
END
PAGE three
SKIP network: three.js r170 did not load from the CDN: Load failed
END
PAGE cut
PASS a: b
EOF
expect webgpu-tri "PASS" "$(check_webgpu "$T/wg" tri)" "2 checks"
expect webgpu-sample "FAIL" "$(check_webgpu "$T/wg" sample)" "1 failed, 1 passed: fragCoord/uniform (120,90)"
expect webgpu-three-offline "SKIP" "$(check_webgpu "$T/wg" three)" "needs network"
expect webgpu-cut "FAIL" "$(check_webgpu "$T/wg" cut)" "cut short"
expect webgpu-missing "FAIL" "$(check_webgpu "$T/wg" nothere)" "no result posted"
expect webgpu-nolog "FAIL" "$(check_webgpu "$T/none" tri)" "no result posted"

# ── time box ───────────────────────────────────────────────────────────────────────────────────────────────────────────
t0=$(date +%s); tbox 1 sleep 20 2>/dev/null; st=$?; dt=$(( $(date +%s) - t0 ))
expect tbox-timeout "PASS" "$([ $st = 124 ] && [ $dt -le 6 ] && echo PASS || echo FAIL)${TAB}status $st after $dt s"
tbox 5 sh -c 'exit 3'; st=$?
expect tbox-status "PASS" "$([ $st = 3 ] && echo PASS || echo FAIL)${TAB}status $st"
t0=$(date +%s); tbox 1 sh -c 'sleep 20 & sleep 20; wait' 2>/dev/null; st=$?; dt=$(( $(date +%s) - t0 ))
expect tbox-group "PASS" "$([ $st = 124 ] && [ $dt -le 6 ] && echo PASS || echo FAIL)${TAB}status $st after $dt s (children ended with the group)"
tbox 5 /nonexistent/x 2>/dev/null; st=$?
expect tbox-missing "PASS" "$([ $st = 127 ] && echo PASS || echo FAIL)${TAB}status $st"

# ── table ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
printf 'kext\tPASS\tIntelXe 0.1.4\nvtdec_h264\tFAIL\truns differ\nwebgpu:three\tSKIP\tneeds network\nsensors\tWARN\ttemperature\n' >"$T/res"
table "$T/res" >"$T/table"
expect table "PASS" "$(grep -q '^overall: FAIL (1 pass, 1 fail, 1 warn, 1 skip)$' "$T/table" && grep -q '^webgpu:three | SKIP   | needs network$' "$T/table" && echo PASS || echo FAIL)${TAB}$(head -3 "$T/table" | tr '\n' '/')"
printf 'kext\tPASS\tok\n' >"$T/res1"
expect table-pass "PASS" "$(table "$T/res1" | grep -q '^overall: PASS (1 pass, 0 fail, 0 warn, 0 skip)$' && echo PASS || echo FAIL)${TAB}"

echo
cat "$T/table"
echo
echo "selftest: $((n - bad)) of $n as expected"
[ $bad = 0 ]
