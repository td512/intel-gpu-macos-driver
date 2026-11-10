#!/bin/bash
# SPDX-License-Identifier: MIT
# regress.sh: the hardware regression checks of the IntelXe stack, run ON the test machine (an Arc B580/B570 with the
# driver installed), ending in one table "stage | result | numbers" and an exit code (0: no FAIL, 1: a FAIL, 2: usage).
# Uses only what macOS has without developer tools: bash 3.2, perl, awk, sysctl, kmutil, /usr/bin/log, ps, open,
# killall, screencapture, curl. Never reboots, never writes the EFI, /Library or the system volume, never changes a
# sysctl; the only process it ends is Safari (killall, and only when it started it) and its own page server.
#
#   tools/regress/regress.sh                 the quick set (~3 min)
#   tools/regress/regress.sh --full          + vcbench (hardware vs software decode), Safari WebGPU pages, Geekbench 7
#   tools/regress/regress.sh --only ufence,metal --skip vtdec_hevc
#   tools/regress/regress.sh --list          the stages and what they need
#
# Logs: $REGRESS_HOME/<timestamp>/ (default ~/b580/regress), one file per stage, results.tsv and summary.txt;
# $REGRESS_HOME/latest points at the newest run. Inputs and settings: README.md next to this file.

# ── settings (environment, or $REGRESS_HOME/regress.conf, a bash file of VAR=value lines) ─────────────────────────────
REGRESS_HOME=${REGRESS_HOME:-$HOME/b580/regress}
[ -f "${REGRESS_CONF:-$REGRESS_HOME/regress.conf}" ] && . "${REGRESS_CONF:-$REGRESS_HOME/regress.conf}"
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
BIN=${REGRESS_BIN:-$REGRESS_HOME/bin}                     # mtl_smoke mtl_cube_read mtl_props mtl_f32filter mtl_timestamps mtl_gpu_icb ufence vtdec vcbench srv
CLIPS=${REGRESS_CLIPS:-$REGRESS_HOME/clips}               # h264.* and hevc.* unless REGRESS_H264 / REGRESS_HEVC name files
GB=${REGRESS_GB:-/Applications/Geekbench 7.app/Contents/Resources/geekbench_avx2}
GB_DEVICE=${REGRESS_GB_DEVICE:-}                          # --gpu-device-id for Geekbench, empty: Geekbench's default
GB_METAL_MIN=${REGRESS_GB_METAL_MIN:-0}                   # a score below these is a WARN (scores are noisy: not a FAIL)
GB_OPENCL_MIN=${REGRESS_GB_OPENCL_MIN:-0}
BOOT_GUARD_MIN=${REGRESS_BOOT_GUARD_MIN:-20}              # no benchmark this soon after boot (indexing) unless --force
VCT=${REGRESS_VCT:-/Applications/Video Codec Test.app/Contents/Resources}
VCT_SETS=${REGRESS_VCT_SETS:-}                            # space-separated set names; empty: every folder with a desc.*
PORT=${REGRESS_PORT:-8765}
PAGES=${REGRESS_PAGES:-$SELF_DIR/pages}
WEBGPU_PAGES=${REGRESS_WEBGPU_PAGES:-tri sample three sweep}   # three needs the network (three.js from the CDN)
POWER_MIN=5; POWER_MAX=400                                # plausible card power, W
TAB=$'\t'

# ── pure helpers: parsing and verdicts (selftest.sh runs these against sample outputs) ─────────────────────────────────
# Every check_* prints "RESULT<TAB>numbers" with RESULT one of PASS WARN FAIL SKIP.

# tbox SECS CMD...: CMD in its own process group with stdin from /dev/null; after SECS seconds TERM to the group, KILL
# 3 s later, exit 124. Ctrl-C / TERM to regress.sh reach the group too. Exit status otherwise CMD's (128+n on signal n).
tbox() {
	perl -MPOSIX=:sys_wait_h -e '
		my $t = shift @ARGV;
		my $pid = fork; die "fork: $!\n" unless defined $pid;
		if (!$pid) { setpgrp(0, 0); exec { $ARGV[0] } @ARGV or do { print STDERR "regress: cannot run $ARGV[0]: $!\n"; exit 127 } }
		setpgrp($pid, $pid);
		my $stop = sub {   # TERM to the group; KILL to what is left of it after 3 s
			kill "TERM", -$pid;
			for (1 .. 30) { waitpid($pid, WNOHANG); last unless kill 0, -$pid; select undef, undef, undef, 0.1 }
			kill "KILL", -$pid; waitpid($pid, 0) };
		$SIG{INT} = $SIG{TERM} = sub { $stop->(); exit 130 };
		$SIG{ALRM} = sub { $stop->(); print STDERR "regress: timed out after ${t} s: @ARGV\n"; exit 124 };
		alarm $t; waitpid($pid, 0); my $st = $?; alarm 0;
		exit($st & 127 ? 128 + ($st & 127) : $st >> 8);' "$@" </dev/null
}

# ver_kmutil < kmutil showloaded: "IntelXe 0.1.4, IntelXeFB 0.1.4, NMXAccel 1.0" (the stack's kexts that are loaded)
ver_kmutil() {
	perl -ne 'while (/(\S+)\.(IntelXe|IntelXeFB|NMXAccel|NMXAGDC|HybridPM) \(([^)]*)\)/g) { $v{$2} = $3 }
		END { print join(", ", map { "$_ $v{$_}" } grep { exists $v{$_} } qw(IntelXe IntelXeFB NMXAccel NMXAGDC HybridPM)) }'
}

# check_kext FILE [REPO_VERSION]: IntelXe must be loaded; another version than the checkout's is a WARN.
check_kext() {
	local v; v=$(ver_kmutil <"$1")
	local x; x=$(printf '%s' "$v" | perl -ne 'print $1 if /(?:^|, )IntelXe ([^,]+)/')
	if [ -z "$x" ]; then printf 'FAIL\tIntelXe not loaded%s\n' "${v:+ ($v)}"; return; fi
	if [ -n "${2:-}" ] && [ "$x" != "$2" ]; then printf 'WARN\t%s; checkout is %s\n' "$v" "$2"; return; fi
	printf 'PASS\t%s\n' "$v"
}

# check_platform FILE: the start line "IntelXe: 8086:xxxx: <platform>, graphics a.b, media c.d, discrete" of this boot
check_platform() {
	perl -e 'my ($ok, $bad) = ("", "");
		while (<>) {
			$ok = "$1:$2" if /IntelXe: 8086:([0-9a-f]{4}): (.+?), graphics [0-9.]+, media [0-9.]+, (?:discrete|integrated)/;
			$bad = $1 if /IntelXe: (8086:[0-9a-f]{4}(?::| is| \().*?(?:not starting|not supported yet|the platform needs).*)$/;
		}
		if ($ok) { my ($id, $p) = split /:/, $ok, 2; print "PASS\t8086:$id $p\n" }
		elsif ($bad) { $bad =~ s/\s+$//; print "FAIL\t$bad\n" }
		else { print "FAIL\tno \"IntelXe: 8086:\" start line in this boot'"'"'s log\n" }' "$1"
}

# check_sensors FILE: the second of two debug.intelxe.sensors readings (power needs an earlier one >= 0.5 s old)
check_sensors() {
	grep -v '^[[:space:]]*$' "$1" | tail -n 1 | perl -ne '
		my %f; $f{act} = $1 if /\bact (\d+) MHz/; $f{rp0} = $1 if /RP0 (\d+) MHz/; $f{pkg} = $1 if /package (\d+) C/;
		$f{vram} = $1 if /VRAM (\d+) C/; $f{card} = $1 if /card power ([0-9.]+) W/; $f{pw} = $1 if /package power ([0-9.]+) W/;
		if (!/\bact \d+ MHz/) { chomp; print "FAIL\tdebug.intelxe.sensors: ", ($_ eq "" ? "empty" : $_), "\n"; exit }
		my $n = sprintf "card %s W, package %s W, GPU %s C, VRAM %s C, act %s MHz, RP0 %s MHz",
			map { defined $f{$_} ? $f{$_} : "?" } qw(card pw pkg vram act rp0);
		if (!defined $f{card}) { print "FAIL\tno card power field ($n)\n"; exit }
		if ($f{card} < '"$POWER_MIN"' || $f{card} > '"$POWER_MAX"') { print "FAIL\tcard power out of '"$POWER_MIN..$POWER_MAX"' W: $n\n"; exit }
		for (qw(pkg vram)) { if (!defined $f{$_} || $f{$_} < 10 || $f{$_} > 110) { print "WARN\ttemperature out of 10..110 C: $n\n"; exit } }
		print "PASS\t$n\n";'
}

# stats_counters < debug.intelxe.stats: "name value" lines of the health counters
stats_counters() {
	perl -0777 -ne '
		my @k = (
			[guc_resets  => qr/GuC context resets (\d+)/], [gt_resets => qr/GT resets (\d+)/],
			[bans        => qr/; bans (\d+)/],             [watchdog_bans => qr/bans \d+ \(watchdog (\d+)\)/],
			[page_faults => qr/page faults (\d+)/],         [h2g_dead => qr/H2G full \d+, dead (\d+)/],
			[tlb_timeouts => qr/\), timeouts (\d+), in-ring/], [leaked => qr/leaked (\d+)/],
			[fast_req_fail => qr/FAST_REQUEST failures (\d+)/], [move_fails => qr/BO moves:.*?failed (\d+)/],
			[uf_timeouts => qr/user fences:.*?timed out (\d+)/]);
		my $s = $_;
		for my $e (@k) { my ($n, $r) = @$e; print "$n ", ($s =~ $r ? $1 : "?"), "\n" }
		print "wedged ", ($s =~ /WEDGED/ ? 1 : 0), "\n";'
}

# check_stats BEFORE AFTER: counter deltas over the run. A GPU reset, a watchdog ban, a dead H2G channel, a TLB timeout
# or WEDGED fails; other bans, page faults and leaked queues warn (the tests may provoke none of them).
check_stats() {
	perl -e '
		my (%a, %b);
		for ([\%a, $ARGV[0]], [\%b, $ARGV[1]]) { my ($h, $f) = @$_; open my $fh, "<", $f or next; while (<$fh>) { $h->{$1} = $2 if /^(\S+) (\S+)$/ } }
		if (!%a || !%b || grep { !defined $b{$_} || $b{$_} eq "?" } qw(gt_resets guc_resets)) { print "FAIL\tdebug.intelxe.stats unreadable\n"; exit }
		my (@fail, @warn, @all);
		for my $k (qw(gt_resets guc_resets watchdog_bans h2g_dead tlb_timeouts wedged bans page_faults leaked fast_req_fail move_fails)) {
			next if !defined $a{$k} || !defined $b{$k} || $a{$k} eq "?" || $b{$k} eq "?";
			my $d = $b{$k} - $a{$k}; next unless $d;
			if ($k =~ /^(gt_resets|guc_resets|watchdog_bans|h2g_dead|tlb_timeouts|wedged)$/) { push @fail, "$k +$d" } else { push @warn, "$k +$d" }
		}
		my $tot = "since boot: GT resets $b{gt_resets}, GuC resets $b{guc_resets}, bans $b{bans}";
		if (@fail) { print "FAIL\t", join(", ", @fail, @warn), " ($tot)\n" }
		elsif (@warn) { print "WARN\t", join(", ", @warn), " ($tot)\n" }
		else { print "PASS\tno new resets, bans, faults ($tot)\n" }' "$1" "$2"
}

# check_ufence FILE STATUS: "N checks, 0 failed"
check_ufence() {
	perl -e 'my $st = $ARGV[1]; open my $f, "<", $ARGV[0] or die; my ($n, $x);
		while (<$f>) { ($n, $x) = ($1, $2) if /^(\d+) checks, (\d+) failed/ }
		if (!defined $n) { print "FAIL\tno summary line (exit $st)\n" }
		elsif ($x == 0 && $st == 0) { print "PASS\t$n checks, 0 failed\n" }
		else { print "FAIL\t$n checks, $x failed (exit $st)\n" }' "$1" "$2"
}

# check_smoke FILE STATUS: mtl_smoke "PASS: 0 of N values wrong on <device> ..."
check_smoke() {
	perl -e 'my $st = $ARGV[1]; open my $f, "<", $ARGV[0] or die; my ($r, $line);
		while (<$f>) { if (/^(PASS|FAIL): (\d+ of \d+ values wrong)/) { ($r, $line) = ($1, $2) } elsif (!$r && /^FAIL: (.*)/) { $line = $1 } }
		if ($r && $r eq "PASS" && $st == 0) { print "PASS\t$line\n" } else { print "FAIL\t", ($line || "no result line"), " (exit $st)\n" }' "$1" "$2"
}

# check_cube FILE STATUS: mtl_cube_read, per-level PASS lines and the final "PASS: every cube texel ..."
check_cube() {
	perl -e 'my $st = $ARGV[1]; open my $f, "<", $ARGV[0] or die; my ($p, $x, $final, $first) = (0, 0, 0, "");
		while (<$f>) { $p++ if /^PASS .*? level \d+:/; if (/^FAIL/) { $x++; ($first = $_) =~ s/\s+$// unless $first } $final = 1 if /^PASS: every cube texel/ }
		if ($final && !$x && $st == 0) { print "PASS\t$p cube level reads correct\n" }
		else { print "FAIL\t$p passed, $x failed", ($first ? ": $first" : ""), " (exit $st)\n" }' "$1" "$2"
}

# check_props FILE STATUS: mtl_props answers every property (no uncaught exception) and the location is 1 (slot)
check_props() {
	perl -e 'my $st = $ARGV[1]; open my $f, "<", $ARGV[0] or die; my ($loc, $exc, $sp, $bt, $tt) = (undef, "", "", "?", "?");
		while (<$f>) { $loc = $1 if /\blocation (-?\d+)/; $exc = $1 if /(\S*[Ee]xception\S*.*)/; $sp = $1 if /PlacementSparse (\d)/;
			$bt = $1 if /sparseBufferTier (\d+)/; $tt = $1 if /sparseTextureTier (\d+)/ }
		chomp $exc;
		if ($exc) { print "FAIL\texception: $exc\n" }
		elsif (!defined $loc) { print "FAIL\tno location line (exit $st)\n" }
		elsif ($loc != 1 || $st != 0) { print "FAIL\tlocation $loc (want 1), exit $st\n" }
		else { print "PASS\tlocation 1, sparse tiers buffer $bt texture $tt", ($sp ne "" ? ", PlacementSparse $sp" : ""), "\n" }' "$1" "$2"
}

# check_f32filter FILE STATUS: three "PASS <format>: ..." lines
check_f32filter() {
	perl -e 'my $st = $ARGV[1]; open my $f, "<", $ARGV[0] or die; my ($p, @x) = (0);
		while (<$f>) { $p++ if /^PASS (R32Float|RG32Float|RGBA32Float):/; push @x, $1 if /^FAIL (\w+)/ }
		if ($p == 3 && !@x && $st == 0) { print "PASS\t3/3 formats filter (R32F, RG32F, RGBA32F)\n" }
		else { print "FAIL\t$p/3 pass", (@x ? ", failed: @x" : ""), " (exit $st)\n" }' "$1" "$2"
}

# check_timestamps FILE STATUS: mtl_timestamps ends in "PASS (0 failed)"; numbers: the last 4N/N spin ratio
check_timestamps() {
	perl -e 'my $st = $ARGV[1]; open my $f, "<", $ARGV[0] or die; my ($ok, $r, @x) = (0, "");
		while (<$f>) { $ok = 1 if /^PASS \(0 failed\)/; $r = $1 if /^compute: .*\(x([\d.]+)\)/; push @x, $1 if /^\s*FAIL: (.*)/ }
		if ($ok && !@x && $st == 0) { print "PASS\tstage-boundary timestamps in ns", ($r ne "" ? ", 4N/N x$r" : ""), "\n" }
		else { print "FAIL\t", (@x ? $x[0] : "no PASS line"), " (exit $st)\n" }' "$1" "$2"
}

# check_gpu_icb FILE STATUS: mtl_gpu_icb, six "PASS slot N" lines (GPU-encoded draws, drawIndexed u32/u16, vsICB, reset)
check_gpu_icb() {
	perl -e 'my $st = $ARGV[1]; open my $f, "<", $ARGV[0] or die; my ($p, @x) = (0);
		while (<$f>) { $p++ if /^PASS slot \d/; push @x, $1 if /^FAIL slot (\d)/ }
		if ($p == 6 && !@x && $st == 0) { print "PASS\t6/6 slots (GPU draw, drawIndexed u32/u16, CPU, vsICB, reset)\n" }
		else { print "FAIL\t$p/6 pass", (@x ? ", failed slots: @x" : ""), " (exit $st)\n" }' "$1" "$2"
}

# vtdec_md5s FILE: the per-frame md5s of a vtdec --md5 run, one per line, in output order
vtdec_md5s() { perl -ne 'print "$1\n" if /^\s*frame \d+ .* md5 ([0-9a-f]{32})/' "$1"; }

# check_vtdec RUN1 RUN2 STATUS1 STATUS2 [REF]: two runs of one clip decode on the hardware without errors and give the
# same pictures; REF (a file with an earlier run's digest) must match too when it exists. Numbers: the clip's digest.
check_vtdec() {
	perl -MDigest::MD5=md5_hex -e '
		my ($r1, $r2, $s1, $s2, $ref) = @ARGV;
		my @run;
		for my $f ($r1, $r2) {
			my %r = (md5 => [], hw => "", codec => "?", st => "?");
			open my $fh, "<", $f or die "$f: $!";
			while (<$fh>) {
				($r{codec}, $r{st}, $r{hw}) = ($1, $2, $3) if /^session \((\S+), hardware required\) -> (-?\d+), using hardware (\w+)/;
				push @{$r{md5}}, $1 if /^\s*frame \d+ .* md5 ([0-9a-f]{32})/;
				@r{qw(sent out err ms)} = ($1, $2, $3, $4) if /^(\d+) samples sent, (\d+) frames out, (\d+) errors, ([0-9.]+) ms/;
			}
			push @run, \%r;
		}
		my ($x, $y) = @run;
		my $why = "";
		if ($s1 || $s2) { $why = "exit $s1/$s2" }
		elsif ($x->{st} ne "0") { $why = "session create $x->{st}" }
		elsif ($x->{hw} ne "yes" || $y->{hw} ne "yes") { $why = "not on the hardware decoder" }
		elsif (!defined $x->{out} || !defined $y->{out}) { $why = "no summary line" }
		elsif ($x->{err} || $y->{err}) { $why = "decode errors $x->{err}/$y->{err}" }
		elsif (!$x->{out}) { $why = "no frames out" }
		elsif (@{$x->{md5}} != $x->{out}) { $why = "frames $x->{out} but md5 lines " . scalar @{$x->{md5}} }
		my $dx = substr(md5_hex(join "", sort @{$x->{md5}}), 0, 12), $dy = substr(md5_hex(join "", sort @{$y->{md5}}), 0, 12);
		if (!$why && $dx ne $dy) {
			my $n = 0; for (0 .. $#{$x->{md5}}) { $n++ if !defined $y->{md5}[$_] || $x->{md5}[$_] ne $y->{md5}[$_] }
			$why = "runs differ: $n of $x->{out} frames"
		}
		my $da = $dx;
		my $nums = "$x->{codec} " . ($x->{out} // 0) . " frames, digest $da, " . ($x->{ms} // "?") . " ms";
		if ($why) { print "FAIL\t$why ($nums)\n"; exit }
		if ($ref && -f $ref) {
			open my $rf, "<", $ref; my $want = <$rf>; chomp $want;
			if ($want ne $da) { print "FAIL\tdigest $da, reference $want ($nums)\n"; exit }
			$nums .= " = reference";
		}
		print "PASS\t$nums, 2 runs identical\n";' "$@"
}

# vtdec_digest RUN: the digest check_vtdec prints (for --save-ref)
vtdec_digest() { perl -MDigest::MD5=md5_hex -e 'my @m; while (<>) { push @m, $1 if /^\s*frame \d+ .* md5 ([0-9a-f]{32})/ } print substr(md5_hex(join "", sort @m), 0, 12), "\n"' "$1"; }

# vcb_fmt FILE: the pixel format of the first summed frame of a vcbench run (420f, 420v, ...)
vcb_fmt() { perl -ne 'if (/^frame pts -?\d+ fmt (\S{4}) /) { print $1; exit }' "$1"; }

# check_vcbench HW SW STATUS_HW STATUS_SW: every picture of the hardware run has the software decoder's checksum
check_vcbench() {
	perl -e '
		my ($hf, $sf, $hs, $ss) = @ARGV;
		my (%h, %s, $hw, $err);
		for ([\%h, $hf], [\%s, $sf]) { my ($m, $f) = @$_; open my $fh, "<", $f or next;
			while (<$fh>) { $m->{$1} = "$2 $3" if /^frame pts (-?\d+) fmt (\S{4}) \S+ sum ([0-9a-f]+)/;
				$hw = $1 if $f eq $hf && /^hardware (\d)/; $err += $1 if /^TOTAL .* errors (\d+)/ } }
		my $n = scalar keys %h;
		my ($diff, $miss, $first) = (0, 0, undef);
		for my $p (sort { $a <=> $b } keys %h) {
			if (!exists $s{$p}) { $miss++; next }
			if ($h{$p} ne $s{$p}) { $diff++; $first //= $p }
		}
		$miss += grep { !exists $h{$_} } keys %s;
		my ($fmt) = map { (split / /)[0] } grep { defined } (values %h)[0];
		if ($hs || $ss) { print "FAIL\texit $hs/$ss\n" }
		elsif (!defined $hw || $hw ne "1") { print "FAIL\thardware decoder not used\n" }
		elsif (!$n) { print "FAIL\tno frames\n" }
		elsif ($diff || $miss) { print "FAIL\t$diff of $n pictures differ from software", ($first // "") ne "" ? " (first pts $first)" : "", ($miss ? ", $miss missing" : ""), "\n" }
		elsif ($err) { print "FAIL\t$err decode errors\n" }
		else { print "PASS\t$n pictures = software ($fmt)\n" }' "$@"
}

# vcb_fps FILE: "TOTAL threads 1: N frames in T s = F fps, errors E" -> F
vcb_fps() { perl -ne 'print $1 if /^TOTAL .* = ([0-9.]+) fps/' "$1"; }

# check_gb FILE STATUS MIN: Geekbench 7 CLI output, "<API> Score  N" and the result URL
check_gb() {
	perl -e 'my ($f, $st, $min) = @ARGV; open my $fh, "<", $f or die; my ($s, $u);
		while (<$fh>) { $s = $1 if /\b(?:GPU|Metal|OpenCL|Vulkan) Score\s+(\d+)/; $u = $1 if m{(https://browser\.geekbench\.com/v\d+/gpu/\d+)} }
		if (!$s) { print "FAIL\tno score (exit $st)\n" }
		elsif ($min && $s < $min) { print "WARN\t$s < $min", ($u ? " $u" : ""), "\n" }
		else { print "PASS\t$s", ($u ? " $u" : ""), "\n" }' "$1" "$2" "$3"
}

# check_webgpu LOG PAGE: the block "PAGE <page>" ... "END" the page posted
check_webgpu() {
	perl -e 'my ($f, $pg) = @ARGV; open my $fh, "<", $f or do { print "FAIL\tno result posted\n"; exit };
		my ($in, $end, $p, $x, $s, @fl, $info) = (0, 0, 0, 0, 0);
		while (<$fh>) { chomp;
			if (/^PAGE (\S+)$/) { $in = ($1 eq $pg); ($p, $x, $s, $end, @fl) = (0, 0, 0, 0) if $in; next }
			next unless $in;
			if ($_ eq "END") { $end = 1; $in = 0; next }
			$p++ if /^PASS /; if (/^FAIL (.*)/) { $x++; push @fl, $1 } $s++ if /^SKIP /; }
		if (!$end && !$p && !$x) { print "FAIL\tno result posted\n" }
		elsif ($x) { print "FAIL\t$x failed, $p passed: $fl[0]\n" }
		elsif (!$end) { print "FAIL\tresult cut short after $p passed\n" }
		elsif (!$p && $s) { print "SKIP\tneeds network (three.js CDN)\n" }
		elsif (!$p) { print "FAIL\tnothing checked\n" }
		else { print "PASS\t$p checks", ($s ? ", $s skipped" : ""), "\n" }' "$1" "$2"
}

# boot_age_s: seconds since boot (kern.boottime "{ sec = N, usec = M } ...")
boot_age_s() { local b; b=$(sysctl -n kern.boottime | perl -ne 'print $1 if /sec = (\d+)/'); echo $(( $(date +%s) - ${b:-0} )); }

# bg_cpu: CPU % of the background indexers that distorted benchmark scores (Spotlight, media analysis)
bg_cpu() {
	ps -A -o %cpu=,comm= | awk '{ c = $1; $1 = ""; n = $0; sub(/^ +/, "", n); sub(/.*\//, "", n)
		if (n ~ /^(mediaanalysisd|mds|mds_stores|mdworker|mdworker_shared|photoanalysisd)$/) s[n] += c }
		END { o = ""; for (k in s) if (s[k] >= 1) o = o sprintf("%s%s %.0f%%", o == "" ? "" : ", ", k, s[k]); print (o == "" ? "indexers idle" : o) }'
}

# table RESULTS.TSV: the summary table and the overall line
table() {
	awk -F'\t' '
		{ st[NR] = $1; rs[NR] = $2; nm[NR] = $3; if (length($1) > w) w = length($1); c[$2]++ }
		END {
			if (w < 5) w = 5
			printf "%-" w "s | %-6s | %s\n", "stage", "result", "numbers"
			l = ""; for (i = 0; i < w; i++) l = l "-"; printf "%s-+--------+-%s\n", l, "--------------------------------"
			for (i = 1; i <= NR; i++) printf "%-" w "s | %-6s | %s\n", st[i], rs[i], nm[i]
			printf "\noverall: %s (%d pass, %d fail, %d warn, %d skip)\n", c["FAIL"] ? "FAIL" : "PASS", c["PASS"], c["FAIL"], c["WARN"], c["SKIP"]
		}' "$1"
}

[ "${REGRESS_LIB:-}" = 1 ] && return 0 2>/dev/null

# ── command line ───────────────────────────────────────────────────────────────────────────────────────────────────────
MODE=quick; ONLY=""; SKIP=""; FORCE=0; NONET=0; SAVEREF=0
STAGES_QUICK="kext platform sensors ufence metal cube_read props f32filter timestamps gpu_icb vtdec_h264 vtdec_hevc stats"
STAGES_FULL="vcbench webgpu gb_metal gb_opencl"
usage() {
	sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
	cat <<EOF

options:
  --quick            the quick set (default): $STAGES_QUICK
  --full             quick + $STAGES_FULL
  --only a,b         only these stages (a prefix selects a group: vtdec, gb, webgpu)
  --skip a,b         leave these out (same names)
  --force            benchmark within $BOOT_GUARD_MIN min of boot; run the Safari pages although Safari was open
  --no-net           skip what needs the network (the three.js page; Geekbench uploads its result)
  --save-ref         record this run's vtdec digests as the references later runs must match
  --list             the stages and their inputs
EOF
}
list_stages() {
	cat <<EOF
quick:
  kext        kmutil showloaded: IntelXe (+ IntelXeFB, NMXAccel, NMXAGDC, HybridPM) loaded, versions
  platform    the kext's "IntelXePlatform" registry property (0.1.4+: the start line), else this boot's log
  sensors     debug.intelxe.sensors twice: power fields present, card power $POWER_MIN..$POWER_MAX W, temperatures
  ufence      \$BIN/ufence: "N checks, 0 failed"
  metal       \$BIN/mtl_smoke: compute fill, 0 values wrong
  cube_read   \$BIN/mtl_cube_read: every cube texel read correct
  props       \$BIN/mtl_props: location 1, no exception
  f32filter   \$BIN/mtl_f32filter: 3 PASS
  timestamps  \$BIN/mtl_timestamps: Metal counter sampling at stage boundaries, ns, PASS (0 failed)
  gpu_icb     \$BIN/mtl_gpu_icb: draws a shader encodes into an indirect command buffer, 6/6 slots
  vtdec_h264  \$BIN/vtdec --md5 twice on \$CLIPS/h264.* (or REGRESS_H264): hardware, no errors, same md5s
  vtdec_hevc  the same on \$CLIPS/hevc.* (or REGRESS_HEVC)
  stats       debug.intelxe.stats at start and end: no new GT/GuC resets, watchdog bans, TLB timeouts
full:
  vcbench     \$BIN/vcbench per Video Codec Test set: hardware vs software checksums of every picture, 1-session fps
  webgpu      \$BIN/srv + Safari: pages/{$(echo $WEBGPU_PAGES | tr ' ' ',')}.html (three: network)
  gb_metal    Geekbench 7 CLI --gpu Metal (refused < $BOOT_GUARD_MIN min after boot unless --force)
  gb_opencl   Geekbench 7 CLI --gpu OpenCL (same guard)
EOF
}
while [ $# -gt 0 ]; do
	case $1 in
		--quick) MODE=quick ;;
		--full) MODE=full ;;
		--only) ONLY=$(echo "${2:-}" | tr ',' ' '); shift ;;
		--only=*) ONLY=$(echo "${1#*=}" | tr ',' ' ') ;;
		--skip) SKIP="$SKIP $(echo "${2:-}" | tr ',' ' ')"; shift ;;
		--skip=*) SKIP="$SKIP $(echo "${1#*=}" | tr ',' ' ')" ;;
		--force) FORCE=1 ;;
		--no-net) NONET=1 ;;
		--save-ref) SAVEREF=1 ;;
		--list) list_stages; exit 0 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "regress: unknown option $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done
[ -n "$ONLY" ] && MODE=full   # --only may name full stages

# want STAGE: in the mode's set, named by --only (or a prefix of it), not named by --skip
want() {
	local s=$1 w
	case " $STAGES_QUICK $([ $MODE = full ] && echo "$STAGES_FULL") " in *" ${s%%:*} "*) ;; *) return 1 ;; esac
	if [ -n "$ONLY" ]; then
		local hit=0   # "vtdec" selects vtdec_h264, "webgpu" webgpu:tri; "webgpu:tri" selects the webgpu stage too
		for w in $ONLY; do case $s in "$w"|"$w"_*|"$w":*) hit=1 ;; esac; case $w in "$s":*) hit=1 ;; esac; done
		[ $hit = 1 ] || return 1
	fi
	for w in $SKIP; do case $s in "$w"|"$w"_*|"$w":*) return 1 ;; esac; done
	return 0
}

# ── run ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
RUN=$REGRESS_HOME/$(date +%Y%m%d-%H%M%S)
mkdir -p "$RUN" || { echo "regress: cannot create $RUN" >&2; exit 2; }
ln -sfn "$RUN" "$REGRESS_HOME/latest" 2>/dev/null
RES=$RUN/results.tsv; : >"$RES"
SRV_PID=""; SAFARI_STARTED=0
cleanup() {
	[ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null
	[ "$SAFARI_STARTED" = 1 ] && killall Safari 2>/dev/null
	SRV_PID=""; SAFARI_STARTED=0
}
trap cleanup EXIT
trap 'cleanup; echo "regress: interrupted" >&2; exit 130' INT TERM

# result STAGE "RESULT<TAB>numbers": one table row (and a progress line)
result() {
	local s=$1 r=${2%%"$TAB"*} n=${2#*"$TAB"}
	[ "$n" = "$2" ] && n=""
	printf '%s\t%s\t%s\n' "$s" "$r" "$n" >>"$RES"
	printf '  %-20s %-4s  %s\n' "$s" "$r" "$n"
}
skip() { result "$1" "SKIP${TAB}$2"; }
need() { [ -x "$BIN/$1" ] || { skip "$2" "no $BIN/$1 (README: prerequisites)"; return 1; }; }

# run_bin SECS LOG CMD...: CMD time-boxed, output to LOG; returns its status. The plugin's allow-list is passed with
# NVMTL_ENABLE=1 (as the tests' own headers say).
run_bin() { local t=$1 log=$2; shift 2; NVMTL_ENABLE=1 tbox "$t" "$@" >"$log" 2>&1; }

REPO_VER=$(cat "$SELF_DIR/../../VERSION" 2>/dev/null)
echo "regress ($MODE) -> $RUN"
{ echo "mode $MODE, only '$ONLY', skip '$SKIP', force $FORCE"; sw_vers; uname -srm; echo "boot age $(boot_age_s) s"; } >"$RUN/env.txt" 2>&1

# stats before anything else runs
sysctl -n debug.intelxe.stats >"$RUN/stats-before.txt" 2>&1
stats_counters <"$RUN/stats-before.txt" >"$RUN/stats-before.cnt"

if want kext; then
	tbox 30 kmutil showloaded >"$RUN/kext.log" 2>&1
	result kext "$(check_kext "$RUN/kext.log" "$REPO_VER")"
fi

if want platform; then
	tbox 90 /usr/bin/log show --last boot --style compact \
		--predicate 'processID == 0 AND eventMessage BEGINSWITH "IntelXe: 8086:"' >"$RUN/platform.log" 2>&1
	# the kext publishes the same line in the registry ("IntelXePlatform"): the boot log rarely keeps it
	ioreg -r -c IntelXe -d 1 -l 2>/dev/null | sed -n 's/.*"IntelXePlatform" = "\(.*\)".*/IntelXe: \1/p' >>"$RUN/platform.log"
	result platform "$(check_platform "$RUN/platform.log")"
fi

if want sensors; then
	{ tbox 10 sysctl -n debug.intelxe.sensors; sleep 1.5; tbox 10 sysctl -n debug.intelxe.sensors; } >"$RUN/sensors.log" 2>&1
	result sensors "$(check_sensors "$RUN/sensors.log")"
fi

if want ufence && need ufence ufence; then
	run_bin 90 "$RUN/ufence.log" "$BIN/ufence"; st=$?
	result ufence "$(check_ufence "$RUN/ufence.log" $st)"
fi

if want metal && need mtl_smoke metal; then
	run_bin 60 "$RUN/metal.log" "$BIN/mtl_smoke"; st=$?
	result metal "$(check_smoke "$RUN/metal.log" $st)"
fi
if want cube_read && need mtl_cube_read cube_read; then
	run_bin 60 "$RUN/cube_read.log" "$BIN/mtl_cube_read"; st=$?
	result cube_read "$(check_cube "$RUN/cube_read.log" $st)"
fi
if want props && need mtl_props props; then
	run_bin 60 "$RUN/props.log" "$BIN/mtl_props"; st=$?
	result props "$(check_props "$RUN/props.log" $st)"
fi
if want f32filter && need mtl_f32filter f32filter; then
	run_bin 60 "$RUN/f32filter.log" "$BIN/mtl_f32filter"; st=$?
	result f32filter "$(check_f32filter "$RUN/f32filter.log" $st)"
fi
if want timestamps && need mtl_timestamps timestamps; then
	run_bin 60 "$RUN/timestamps.log" "$BIN/mtl_timestamps"; st=$?
	result timestamps "$(check_timestamps "$RUN/timestamps.log" $st)"
fi
if want gpu_icb && need mtl_gpu_icb gpu_icb; then
	run_bin 60 "$RUN/gpu_icb.log" "$BIN/mtl_gpu_icb"; st=$?
	result gpu_icb "$(check_gpu_icb "$RUN/gpu_icb.log" $st)"
fi

# vtdec: one clip, twice, every frame's md5
for codec in h264 hevc; do
	s=vtdec_$codec
	want $s || continue
	need vtdec $s || continue
	clip=$([ $codec = h264 ] && echo "${REGRESS_H264:-}" || echo "${REGRESS_HEVC:-}")
	[ -z "$clip" ] && for c in "$CLIPS/$codec".*; do [ -f "$c" ] && { clip=$c; break; }; done
	[ -f "$clip" ] || { skip $s "no clip ($CLIPS/$codec.* or REGRESS_$(echo $codec | tr a-z A-Z))"; continue; }
	echo "clip $clip" >"$RUN/$s.clip"
	VT_INTELXE_METAL=1 run_bin 90 "$RUN/$s-1.log" "$BIN/vtdec" "$clip" 60 --md5; s1=$?
	VT_INTELXE_METAL=1 run_bin 90 "$RUN/$s-2.log" "$BIN/vtdec" "$clip" 60 --md5; s2=$?
	ref=$REGRESS_HOME/ref/$s.digest
	result $s "$(check_vtdec "$RUN/$s-1.log" "$RUN/$s-2.log" $s1 $s2 "$([ $SAVEREF = 1 ] || echo "$ref")")"
	if [ $SAVEREF = 1 ] && [ "$(tail -n 1 "$RES" | cut -f2)" = PASS ]; then
		mkdir -p "$REGRESS_HOME/ref" && vtdec_digest "$RUN/$s-1.log" >"$ref" && echo "  saved reference $ref"
	fi
done

# vcbench: per Video Codec Test set, the hardware decoder in its own output format, then Apple's software decoder asked
# for that format; every picture's checksum must match. Then 3 s of single-session hardware throughput.
if want vcbench; then
	if ! need vcbench vcbench; then :
	elif [ ! -d "$VCT" ]; then skip vcbench "no $VCT"
	else
		sets=$VCT_SETS
		[ -z "$sets" ] && for d in "$VCT"/*/; do ls "$d"desc.* >/dev/null 2>&1 && sets="$sets $(basename "$d")"; done
		[ -z "$sets" ] && skip vcbench "no set with desc.* in $VCT"
		for set in $sets; do
			s=vcbench:$set; want "$s" || continue
			d=$VCT/$set
			VCB_PS=1 VCB_SUM=1 run_bin 180 "$RUN/vcb-$set-hw.log" "$BIN/vcbench" "$d" 0.01 one none 0; hs=$?
			f=$(vcb_fmt "$RUN/vcb-$set-hw.log")
			case $f in 420f|420v) sf=$f ;; BGRA) sf=bgra ;; *) sf=none ;; esac   # none: a format mismatch shows as a FAIL
			VCB_SW=1 VCB_PS=1 VCB_SUM=1 run_bin 300 "$RUN/vcb-$set-sw.log" "$BIN/vcbench" "$d" 0.01 one "$sf" 0; ss=$?
			r=$(check_vcbench "$RUN/vcb-$set-hw.log" "$RUN/vcb-$set-sw.log" $hs $ss)
			if [ "${r%%"$TAB"*}" = PASS ]; then
				VCB_PS=1 run_bin 60 "$RUN/vcb-$set-fps.log" "$BIN/vcbench" "$d" 3 one none 1
				fps=$(vcb_fps "$RUN/vcb-$set-fps.log"); r="$r, ${fps:-?} fps (1 session)"
			fi
			result "$s" "$r"
		done
	fi
fi

# webgpu: the pages from $PAGES served on 127.0.0.1 by srv, opened in Safari one by one; each posts its block to
# /log (log.txt in the served copy). Safari is quit with killall when done (an AppleScript quit can block on a prompt).
if want webgpu; then
	if ! need srv webgpu; then :
	elif [ ! -f "$PAGES/common.js" ]; then skip webgpu "no pages in $PAGES"
	elif pgrep -x Safari >/dev/null && [ $FORCE = 0 ]; then skip webgpu "Safari is open (its windows would be lost: close it or --force)"
	elif [ "$(stat -f %Su /dev/console)" = root ]; then skip webgpu "nobody logged in at the console (Safari needs a session)"
	else
		WWW=$RUN/www; mkdir -p "$WWW"; cp "$PAGES"/*.html "$PAGES"/*.js "$WWW"/
		for p in 0 1 2 3 4 5 6 7 8 9; do   # a free port: nothing answers on it yet
			curl -s -m 2 -o /dev/null "http://127.0.0.1:$PORT/" || break
			PORT=$((PORT + 1))
		done
		"$BIN/srv" "$WWW" "$PORT" >"$RUN/srv.log" 2>&1 </dev/null &
		SRV_PID=$!
		ok=0; for i in 1 2 3 4 5 6 7 8 9 10; do
			[ "$(curl -s -m 2 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/common.js")" = 200 ] && { ok=1; break; }
			sleep 0.5
		done
		if [ $ok = 0 ]; then
			skip webgpu "srv did not answer on 127.0.0.1:$PORT ($(head -c 200 "$RUN/srv.log"))"
		else
			pgrep -x Safari >/dev/null || SAFARI_STARTED=1
			[ $FORCE = 1 ] && SAFARI_STARTED=1
			anyfail=0
			for pg in $WEBGPU_PAGES; do
				s=webgpu:$pg; want "$s" || continue
				[ "$pg" = three ] && [ $NONET = 1 ] && { skip "$s" "needs network (--no-net)"; continue; }
				t=60; [ "$pg" = three ] && t=120
				tbox 30 open -a Safari "http://127.0.0.1:$PORT/$pg.html?run=$(basename "$RUN")" >>"$RUN/webgpu-open.log" 2>&1
				n=0
				while [ $n -lt $t ]; do
					perl -e 'my ($f, $p) = @ARGV; open my $fh, "<", $f or exit 1; my $in = 0;
						while (<$fh>) { chomp; $in = 1 if $_ eq "PAGE $p"; exit 0 if $in && $_ eq "END" } exit 1' "$WWW/log.txt" "$pg" && break
					sleep 1; n=$((n + 1))
				done
				r=$(check_webgpu "$WWW/log.txt" "$pg")
				[ $n -ge $t ] && r="FAIL${TAB}no result after $t s (page hung or WebGPU unavailable)"
				[ "${r%%"$TAB"*}" = FAIL ] && anyfail=1
				result "$s" "$r"
			done
			[ $anyfail = 1 ] && screencapture -x -t jpg "$RUN/webgpu-fail.jpg" 2>/dev/null
			cp "$WWW/log.txt" "$RUN/webgpu.log" 2>/dev/null
		fi
		cleanup
	fi
fi

# Geekbench 7: the B580's Metal and OpenCL scores; refused within BOOT_GUARD_MIN minutes of boot (Spotlight and media
# analysis indexing then cost ~5%) unless --force; the indexers' CPU use at the start goes into the numbers.
for api in Metal OpenCL; do
	s=gb_$(echo $api | tr A-Z a-z)
	want $s || continue
	[ -x "$GB" ] || { skip $s "no Geekbench 7 CLI at $GB"; continue; }
	[ $NONET = 1 ] && { skip $s "Geekbench uploads its result (--no-net)"; continue; }
	age=$(boot_age_s)
	if [ "$age" -lt $((BOOT_GUARD_MIN * 60)) ] && [ $FORCE = 0 ]; then
		skip $s "booted $((age / 60)) min ago (< $BOOT_GUARD_MIN: indexing distorts scores; --force)"; continue
	fi
	bg=$(bg_cpu); who=$(stat -f %Su /dev/console)
	echo "background CPU at start: $bg; console user: $who" >"$RUN/$s.log"
	min=$([ $api = Metal ] && echo "$GB_METAL_MIN" || echo "$GB_OPENCL_MIN")
	t0=$(date +%s)
	if [ -n "$GB_DEVICE" ]; then tbox 900 "$GB" --gpu $api --gpu-device-id "$GB_DEVICE" >>"$RUN/$s.log" 2>&1
	else tbox 900 "$GB" --gpu $api >>"$RUN/$s.log" 2>&1; fi
	st=$?
	r=$(check_gb "$RUN/$s.log" $st "$min")
	r="$r ($(( $(date +%s) - t0 )) s; bg: $bg$([ "$who" = root ] && echo '; NOT logged in: scores low'))"
	result $s "$r"
done

if want stats; then
	sysctl -n debug.intelxe.stats >"$RUN/stats-after.txt" 2>&1
	stats_counters <"$RUN/stats-after.txt" >"$RUN/stats-after.cnt"
	result stats "$(check_stats "$RUN/stats-before.cnt" "$RUN/stats-after.cnt")"
fi

[ -s "$RES" ] || { echo "regress: no stage selected (--list shows them)" >&2; exit 2; }
echo
table "$RES" | tee "$RUN/summary.txt"
echo "logs: $RUN"
awk -F"\t" '$2 == "FAIL" { f = 1 } END { exit !f }' "$RES" && exit 1
exit 0
