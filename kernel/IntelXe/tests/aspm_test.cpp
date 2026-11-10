// SPDX-License-Identifier: MIT
// aspm_test: offline check of the ASPM path logic (xe_aspm.h), no GPU needed.
//   1. latency decoding equals Linux aspm.c calc_l0s_latency / calc_l1_latency / calc_l*_acceptable
//   2. link detection: root/downstream port above an endpoint or upstream port is a link; DSP under USP is not
//   3. the L1 checks: support on both ends (every function), pre-1.1, PCIe present, common clock, endpoint latency
//      with 1 us per link (pcie_aspm_check_latency), endpoints of other links
//   4. the plan: enable from the root port down, disable from the GPU up, disable-first when an ASPM bit is set,
//      L0s kept only where every end has it, multi-function order, nothing for links already in the target state
//   5. the report text decodes the registers
// c++ -std=c++17 -Wall -Wextra -I.. -o aspm_test aspm_test.cpp && ./aspm_test
#include <stdio.h>
#include <string.h>
#include "xe_aspm.h"

static int fails, checks;
#define CHECK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); \
	printf("\n"); } } while (0)

// A PCIe function: L1EL encoding l1e (1 us << e), L0s and L1 support, CCC/SLC, acceptable L1 encoding acc1
static XeAspmFn fn(uint16_t dev, uint8_t type, uint32_t l1e = 2, bool l1 = true, bool l0s = true, bool ccc = true,
	bool slc = true, uint32_t acc1 = 7, uint16_t aspm = 0, uint8_t func = 0) {
	XeAspmFn f = {};
	f.vendor = 0x8086;
	f.device = dev;
	f.fn = func;
	f.pcie = true;
	f.type = type;
	f.devCap = XE_DEVCAP_RBER | acc1 << 9 | 7u << 6;
	f.lnkCap = (l0s ? XE_LNKCAP_ASPM_L0S : 0) | (l1 ? XE_LNKCAP_ASPM_L1 : 0) | 3u << 12 | l1e << 15;
	f.lnkCtl = (uint16_t)((ccc ? XE_LNKCTL_CCC : 0) | aspm);
	f.lnkSta = (uint16_t)((slc ? XE_LNKSTA_SLC : 0) | 4 | 16 << 4);
	return f;
}

// The B580 path: link 0 = DSP e2f0 <-> GPU e20b, link 1 = root port <-> USP e2ff
static void b580(XeAspmLink *l, XeAspmEndpoint *eps, uint32_t *nEps, uint32_t gpuAcc = 6) {
	memset(l, 0, 2 * sizeof *l);
	l[0].up = fn(0xe2f0, XE_PCIE_DOWNSTREAM);
	l[0].down[0] = fn(0xe20b, XE_PCIE_ENDPOINT, 2, true, true, true, true, gpuAcc);
	l[0].nDown = 1;
	l[1].up = fn(0xa70d, XE_PCIE_ROOT_PORT, 4);
	l[1].down[0] = fn(0xe2ff, XE_PCIE_UPSTREAM, 3);
	l[1].nDown = 1;
	eps[0] = XeAspmEndpoint{0x8086, 0xe20b, 3, 0, 0, l[0].down[0].devCap, 0, 0};
	*nEps = 1;
}

int main() {
	// 1. aspm.c:478-512
	CHECK(xeAspmL0sExitNs(0) == 64 && xeAspmL0sExitNs(6u << 12) == 4096 && xeAspmL0sExitNs(7u << 12) == 5000, "L0s exit");
	CHECK(xeAspmL1ExitNs(0) == 1000 && xeAspmL1ExitNs(6u << 15) == 64000 && xeAspmL1ExitNs(7u << 15) == 65000, "L1 exit");
	CHECK(xeAspmL0sAcceptableNs(0) == 64 && xeAspmL0sAcceptableNs(5u << 6) == 2048 && xeAspmL0sAcceptableNs(7u << 6) == UINT32_MAX,
		"L0s acceptable");
	CHECK(xeAspmL1AcceptableNs(0) == 1000 && xeAspmL1AcceptableNs(6u << 9) == 64000 && xeAspmL1AcceptableNs(7u << 9) == UINT32_MAX,
		"L1 acceptable");

	// 2. links
	CHECK(xeAspmIsLink(XE_PCIE_DOWNSTREAM, XE_PCIE_ENDPOINT), "DSP-endpoint");
	CHECK(xeAspmIsLink(XE_PCIE_ROOT_PORT, XE_PCIE_UPSTREAM), "RP-USP");
	CHECK(xeAspmIsLink(XE_PCIE_ROOT_PORT, XE_PCIE_LEG_END), "RP-legacy endpoint");
	CHECK(!xeAspmIsLink(XE_PCIE_UPSTREAM, XE_PCIE_DOWNSTREAM), "USP-DSP is inside the switch");
	CHECK(!xeAspmIsLink(XE_PCIE_ENDPOINT, XE_PCIE_ENDPOINT), "endpoint-endpoint");

	// 3. checks
	XeAspmLink l[2];
	XeAspmEndpoint eps[XE_ASPM_MAX_EPS];
	uint32_t ne = 0;
	b580(l, eps, &ne);
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_OK, "B580 link 0: %u", xeAspmL1Check(l, 2, 0, eps, ne).why);
	CHECK(xeAspmL1Check(l, 2, 1, eps, ne).why == XE_ASPM_OK, "B580 link 1: %u", xeAspmL1Check(l, 2, 1, eps, ne).why);
	CHECK(xeAspmL1Check(l, 2, 2, eps, ne).why == XE_ASPM_NO_FN, "link index past the path");

	// latency: link 1 exit = max(RP 16 us, USP 8 us) + 1 us for the link below = 17 us
	b580(l, eps, &ne, 4);   // GPU accepts 16 us
	XeAspmVerdict v = xeAspmL1Check(l, 2, 1, eps, ne);
	CHECK(v.why == XE_ASPM_LATENCY && v.latencyNs == 17000 && v.acceptableNs == 16000, "link 1 latency: %u %u %u", v.why,
		v.latencyNs, v.acceptableNs);
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_OK, "link 0: 4 us within 16 us");
	b580(l, eps, &ne, 5);   // 32 us: both fine
	CHECK(xeAspmL1Check(l, 2, 1, eps, ne).why == XE_ASPM_OK, "link 1 within 32 us");
	b580(l, eps, &ne, 1);   // 2 us: link 0's own 4 us fails
	v = xeAspmL1Check(l, 2, 0, eps, ne);
	CHECK(v.why == XE_ASPM_LATENCY && v.latencyNs == 4000 && v.acceptableNs == 2000, "link 0 latency %u", v.latencyNs);
	// an endpoint behind another downstream port (audio): only link 1, 1 link below it
	b580(l, eps, &ne);
	eps[ne++] = XeAspmEndpoint{0x8086, 0xe2f7, 5, 0, 0, XE_DEVCAP_RBER | 4u << 9, 1, 1};
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_OK, "audio does not constrain the GPU's link");
	v = xeAspmL1Check(l, 2, 1, eps, ne);
	CHECK(v.why == XE_ASPM_LATENCY && v.index == 1 && v.latencyNs == 17000, "audio constrains link 1: %u %u", v.why, v.latencyNs);

	b580(l, eps, &ne);
	l[1].up.lnkCap &= ~XE_LNKCAP_ASPM_L1;
	CHECK(xeAspmL1Check(l, 2, 1, eps, ne).why == XE_ASPM_NO_L1_UP, "root port without L1");
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_OK, "the other link unaffected");
	b580(l, eps, &ne);
	l[0].down[1] = fn(0xe2f7, XE_PCIE_ENDPOINT, 2, false, true, true, true, 7, 0, 1);
	l[0].nDown = 2;
	v = xeAspmL1Check(l, 2, 0, eps, ne);
	CHECK(v.why == XE_ASPM_NO_L1_DOWN && v.index == 1, "function 1 without L1");
	b580(l, eps, &ne);
	l[0].down[0].devCap &= ~XE_DEVCAP_RBER;
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_PRE_1_1, "pre-1.1");
	b580(l, eps, &ne);
	l[0].down[0].pcie = false;
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_NOT_PCIE, "not PCIe");
	b580(l, eps, &ne);
	l[0].down[0].lnkCtl &= (uint16_t)~XE_LNKCTL_CCC;
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_CCC_INCONSISTENT, "CCC on one end only");
	b580(l, eps, &ne);
	l[0].up.lnkCtl &= (uint16_t)~XE_LNKCTL_CCC;
	l[0].down[0].lnkCtl &= (uint16_t)~XE_LNKCTL_CCC;
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_CCC_NOT_SET, "shared clock, CCC clear");
	l[0].down[0].lnkSta &= (uint16_t)~XE_LNKSTA_SLC;
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_OK, "separate clocks, CCC clear: allowed");
	b580(l, eps, &ne);
	l[0].nDown = 0;
	CHECK(xeAspmL1Check(l, 2, 0, eps, ne).why == XE_ASPM_NO_FN, "no function");
	b580(l, eps, &ne);
	CHECK(xeAspmL1Check(l, 2, 0, eps, XE_ASPM_MAX_EPS + 1).why == XE_ASPM_TOO_MANY, "too many endpoints");

	// 4. plan
	XeAspmStep st[64];
	b580(l, eps, &ne);
	uint32_t n = xeAspmPlan(l, 2, 1, st, 64);
	CHECK(n == 2 && st[0].link == 1 && st[0].state == XE_LNKCTL_ASPM_L1 && st[1].link == 0 && st[1].state == XE_LNKCTL_ASPM_L1,
		"enable from the root port down: n %u [%u %u] [%u %u]", n, st[0].link, st[0].state, st[1].link, st[1].state);
	CHECK(xeAspmPlan(l, 2, 0, st, 64) == 0, "disable with ASPM already off: nothing");
	CHECK(xeAspmPlan(l, 2, -1, st, 64) == 0, "-1: nothing");
	// L1 already on both links: nothing to do; disable goes from the GPU up
	l[0].up.lnkCtl |= XE_LNKCTL_ASPM_L1, l[0].down[0].lnkCtl |= XE_LNKCTL_ASPM_L1;
	l[1].up.lnkCtl |= XE_LNKCTL_ASPM_L1, l[1].down[0].lnkCtl |= XE_LNKCTL_ASPM_L1;
	CHECK(xeAspmPlan(l, 2, 1, st, 64) == 0, "L1 already on");
	n = xeAspmPlan(l, 2, 0, st, 64);
	CHECK(n == 2 && st[0].link == 0 && st[0].state == 0 && st[1].link == 1 && st[1].state == 0, "disable from the GPU up");
	// L0s on both ends of link 1 stays; L1 on one end only of link 0: disabled first, then enabled
	b580(l, eps, &ne);
	l[1].up.lnkCtl |= XE_LNKCTL_ASPM_L0S, l[1].down[0].lnkCtl |= XE_LNKCTL_ASPM_L0S;
	l[0].up.lnkCtl |= XE_LNKCTL_ASPM_L1;
	n = xeAspmPlan(l, 2, 1, st, 64);
	CHECK(n == 4, "steps %u", n);
	CHECK(st[0].link == 1 && st[0].state == 0 && st[1].link == 1 && st[1].state == (XE_LNKCTL_ASPM_L1 | XE_LNKCTL_ASPM_L0S),
		"link 1: off, then L0s+L1 (%u %u)", st[0].state, st[1].state);
	CHECK(st[2].link == 0 && st[2].state == 0 && st[3].link == 0 && st[3].state == XE_LNKCTL_ASPM_L1,
		"link 0: off, then L1 (L0s dropped)");
	// L0s on one end only: dropped
	b580(l, eps, &ne);
	l[0].down[0].lnkCtl |= XE_LNKCTL_ASPM_L0S;
	n = xeAspmPlan(l, 2, 1, st, 64);
	CHECK(n == 3 && st[0].link == 1 && st[1].link == 0 && st[1].state == 0 && st[2].state == XE_LNKCTL_ASPM_L1, "L0s one end");
	// multi-function: enable function 0 first, disable the highest first
	b580(l, eps, &ne);
	l[0].down[1] = fn(0xe2f7, XE_PCIE_ENDPOINT, 2, true, true, true, true, 7, 0, 1);
	l[0].nDown = 2;
	n = xeAspmPlan(l, 2, 1, st, 64);
	CHECK(n == 3 && st[1].link == 0 && st[1].fn == 0 && st[2].fn == 1, "enable: fn 0 then fn 1");
	l[0].up.lnkCtl |= XE_LNKCTL_ASPM_L1, l[0].down[0].lnkCtl |= XE_LNKCTL_ASPM_L1, l[0].down[1].lnkCtl |= XE_LNKCTL_ASPM_L1;
	n = xeAspmPlan(l, 2, 0, st, 64);
	CHECK(n == 2 && st[0].fn == 1 && st[1].fn == 0, "disable: fn 1 then fn 0");
	CHECK(xeAspmPlan(l, 2, 0, st, 1) == 1, "max respected");
	CHECK(xeAspmPlan(l, XE_ASPM_MAX_LINKS + 1, 1, st, 64) == 0, "too many links");
	// link state
	b580(l, eps, &ne);
	CHECK(xeAspmLinkState(l[0]) == 0, "state off");
	l[0].up.lnkCtl |= XE_LNKCTL_ASPM_L1;
	CHECK(xeAspmLinkState(l[0]) == -1, "state differs");

	// 5. report
	char b[2048];
	size_t m = 0;
	b580(l, eps, &ne);
	l[0].down[0].l1ss = true;
	l[0].down[0].l1ssCap = 0x1f;
	l[0].down[0].l1ssCtl1 = 0;
	xeAspmFormatFn(b, sizeof b, &m, "down", l[0].down[0]);
	CHECK(strstr(b, "8086:e20b endpoint") && strstr(b, "ASPM support L0s L1") && strstr(b, "L1 4 us") &&
		strstr(b, "acceptable L0s any L1 64 us") && strstr(b, "ASPM-L1.1 ASPM-L1.2 PCIPM-L1.1 PCIPM-L1.2") &&
		strstr(b, "(enabled none)") && strstr(b, "gen 4 x16"), "report:\n%s", b);
	m = 0;
	v = XeAspmVerdict{XE_ASPM_LATENCY, 0, 17000, 16000};
	xeAspmFormatVerdict(b, sizeof b, &m, v, l[1], eps);
	CHECK(strstr(b, "needs 16000 ns or less, the link gives 17000 ns") != nullptr, "verdict: %s", b);
	m = 0;
	char small[16];
	xeAspmFormatFn(small, sizeof small, &m, "down", l[0].down[0]);
	CHECK(m < sizeof small && strlen(small) == m, "truncation: %zu", m);

	printf("%d checks, %d failures\n", checks, fails);
	return fails != 0;
}
