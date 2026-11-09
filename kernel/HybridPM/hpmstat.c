// SPDX-License-Identifier: MIT
/*
 * hpmstat: diff two HybridPM samples (sysctl debug.hybridpm.state) and print per-CPU effective clock, busy share,
 * HWP request/capabilities and temperature, plus package power from RAPL, the MSR and MCHBAR power limits,
 * perf-limit reasons and EET. No root needed.
 *
 *   hpmstat [interval-ms [count]]     default 1000 ms, 1 sample
 *
 * kernel/HybridPM/build.py builds it next to the kext; by hand: clang -arch x86_64 -O2 -o hpmstat hpmstat.c
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <unistd.h>

#define MAX_CPUS 64
struct HpmCpu { uint64_t aperf, mperf, hwpReq, hwpCap; uint8_t type, temp, pad[6]; };
struct HpmState {
	uint32_t version, ncpu, tjmax, pkgTemp;
	uint64_t tsc, pkgEnergy, iaEnergy, gtEnergy, raplUnit, pkgPowerLimit, mchPowerLimit, perfLimitReasons, powerCtl,
	         turboRatio, turboRatioCores, platformInfo;
	struct HpmCpu cpu[MAX_CPUS];
};

static int sample(struct HpmState *s)
{
	size_t len = sizeof(*s);
	if (sysctlbyname("debug.hybridpm.state", s, &len, NULL, 0) || len != sizeof(*s) || s->version != 1) {
		perror("debug.hybridpm.state");
		return -1;
	}
	return 0;
}

static void limit(const char *name, uint64_t v, double unit)
{
	printf("%s PL1 %.1f W%s tw %u/%u, PL2 %.1f W%s%s", name, (v & 0x7fff) * unit, (v >> 15) & 1 ? "" : " (off)",
	       (unsigned)(v >> 17) & 0x1f, (unsigned)(v >> 22) & 3, ((v >> 32) & 0x7fff) * unit, (v >> 47) & 1 ? "" : " (off)",
	       (v >> 63) & 1 ? ", locked" : "");
}

static const char *reasons[16] = {"PROCHOT", "THERMAL", NULL, NULL, "RSR", "RATL", "VR_THERMAL", "VR_TDC", "OTHER",
	NULL, "PL1", "PL2", "MAX_TURBO", "TURBO_ATTEN", NULL, NULL};

int main(int argc, char **argv)
{
	int ms = argc > 1 ? atoi(argv[1]) : 1000, count = argc > 2 ? atoi(argv[2]) : 1;
	static struct HpmState a, b;
	if (sample(&a))
		return 1;
	const double base = ((a.platformInfo >> 8) & 0xff) * 100.0;
	const double punit = 1.0 / (1 << (a.raplUnit & 0xf)), eunit = 1.0 / (1 << ((a.raplUnit >> 8) & 0x1f));
	for (int n = 0; n < count; n++) {
		usleep(ms * 1000);
		if (sample(&b))
			return 1;
		const double dt = (double)(b.tsc - a.tsc) / (base * 1e6);
		printf("pkg %.1f W (IA %.1f W, GT %.1f W), %u C (TjMax %u), base %.0f MHz, EET %s, ",
		       (double)((uint32_t)(b.pkgEnergy - a.pkgEnergy)) * eunit / dt, (double)((uint32_t)(b.iaEnergy - a.iaEnergy)) * eunit / dt,
		       (double)((uint32_t)(b.gtEnergy - a.gtEnergy)) * eunit / dt, b.pkgTemp, b.tjmax, base,
		       (b.powerCtl >> 19) & 1 ? "off" : "on");
		printf("limits now:");
		for (int i = 0; i < 16; i++)
			if (reasons[i] && ((b.perfLimitReasons >> i) & 1))
				printf(" %s", reasons[i]);
		printf(", logged:");
		for (int i = 0; i < 16; i++)
			if (reasons[i] && ((b.perfLimitReasons >> (16 + i)) & 1))
				printf(" %s", reasons[i]);
		printf("\n");
		limit("MSR", b.pkgPowerLimit, punit);
		printf("; ");
		limit("MCHBAR", b.mchPowerLimit, punit);
		printf("\nturbo ratios %016llx cores %016llx\n", (unsigned long long)b.turboRatio, (unsigned long long)b.turboRatioCores);
		printf("cpu type   MHz busy%%  hwp hi/gu/eff/lo  req min/max/des/epp  temp\n");
		for (int c = 0; c < MAX_CPUS; c++) {
			const struct HpmCpu *x = &a.cpu[c], *y = &b.cpu[c];
			if (!y->type)
				continue;
			const double dm = (double)(y->mperf - x->mperf), da = (double)(y->aperf - x->aperf);
			const double busy = dm / (b.tsc - a.tsc) * 100.0, mhz = dm > 0 ? da / dm * base : 0;
			printf("%3d  %s  %5.0f %5.1f   %3u/%3u/%3u/%3u     %3u/%3u/%3u/%3u     %3u\n", c, y->type == 0x40 ? "P" : y->type == 0x20 ? "E" : "?",
			       mhz, busy, (unsigned)(y->hwpCap & 0xff), (unsigned)(y->hwpCap >> 8) & 0xff, (unsigned)(y->hwpCap >> 16) & 0xff,
			       (unsigned)(y->hwpCap >> 24) & 0xff, (unsigned)(y->hwpReq & 0xff), (unsigned)(y->hwpReq >> 8) & 0xff,
			       (unsigned)(y->hwpReq >> 16) & 0xff, (unsigned)(y->hwpReq >> 24) & 0xff, y->temp);
		}
		a = b;
	}
	return 0;
}
