// SPDX-License-Identifier: MIT
//  HybridPM: XCPM fixes and diagnostics for hybrid Alder Lake / Raptor Lake desktop CPUs (Lilu plugin).
//
//  XCPM predates hybrid CPUs. It writes IA32_HWP_REQUEST (0x774) max/desired in 100 MHz ratio units, but hybrid
//  P-cores count HWP performance in units of 78.741 MHz (Linux intel_pstate HYBRID_SCALING_FACTOR_ADL), so the
//  turbo ratio 56 of an i7-14700K becomes 56 * 78.741 = 4.41 GHz on the P-cores. The XCPM routine that builds and
//  writes the request (_xcpm_enable_pstate_ctrs+0x1140 on macOS 15.8.1, +0x1190 on 26.7.1) is routed; after Apple's
//  write the request is converted to HWP units on cores whose HWP_CAPABILITIES highest exceeds the requested max.
//  Same idea as NootedGreen XE-PM (JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe), which found the unit mismatch.
//
//  XCPM also writes its own per-CPU pick from the frequency vector into the request's desired field, which pins the
//  core to that ratio. With CpuTopologyRebuild's SMT grouping it leaves fully busy cores at 800 MHz while others run
//  at 3.3 GHz under the same load. Autonomous mode writes desired 0, so the hardware picks each core's clock from its
//  own load within [min, highest] and EPP, as Linux intel_pstate does.
//
//  Live controls (root): sysctl debug.hybridpm.hwp=0|1, debug.hybridpm.autonomous=0|1, debug.hybridpm.epp=-1|0..255
//  (-1 keeps XCPM's EPP), debug.hybridpm.eet_off=0|1 (energy-efficient turbo, MSR_POWER_CTL bit 19). Boot-args:
//  -hpmoff (Lilu), hpmhwp=0, hpmauto=0, hpmepp=N, hpmeet=0. Defaults: conversion on, autonomous, EPP 0, EET off.
//  On an i7-14700K (perl loop, M iterations/s) these took one thread from a median of ~55 to 128 (5.39 GHz), eight
//  threads from ~400 to ~1010 and 28 threads from 920-1365 to ~1500 (PL2 253 W either way); idle package power stayed
//  ~10 W for every EPP. Everything takes effect 20 s after boot: HWP MSRs #GP before XCPM sets IA32_PM_ENABLE.
//
//  debug.hybridpm.state (read-only, any user) returns HpmState below: per-CPU APERF/MPERF, HWP capabilities and
//  request, core type and temperature, plus package RAPL energy, power limits (MSR 0x610 and the MCHBAR copy at
//  0x59A0, the lower one applies), perf-limit reasons and turbo ratio limits. hpmstat diffs two samples.
#include <Headers/plugin_start.hpp>
#include <Headers/kern_api.hpp>
#include <Headers/kern_patcher.hpp>
#include <IOKit/IOLib.h>
#include <IOKit/IOMemoryDescriptor.h>
#include <IOKit/pci/IOPCIDevice.h>
#include <kern/thread_call.h>
#include <sys/sysctl.h>

static inline uint64_t rdmsr64(uint32_t m) { uint32_t lo, hi; asm volatile("rdmsr" : "=a"(lo), "=d"(hi) : "c"(m)); return ((uint64_t)hi << 32) | lo; }
static inline void wrmsr64(uint32_t m, uint64_t v) { asm volatile("wrmsr" : : "c"(m), "a"((uint32_t)v), "d"((uint32_t)(v >> 32))); }
static inline uint32_t cpuidEax(uint32_t leaf) { uint32_t a, b, c, d; asm volatile("cpuid" : "=a"(a), "=b"(b), "=c"(c), "=d"(d) : "a"(leaf), "c"(0)); return a; }

static constexpr int MaxCpus = 64;
static constexpr uint32_t HybridScale = 78741;   // P-core kHz per HWP performance unit (ADL/RPL)

using RendezvousFn = void (*)(void (*)(void *), void *);
using CpuNumberFn = int (*)();
static RendezvousFn rendezvous;
static CpuNumberFn cpuNumber;

static int enabled, hwpOn = 1, autonomous = 1, eppOverride = 0, eetOff = 1, route, applied;
static uint8_t coreType[MaxCpus];   // CPUID 0x1A EAX[31:24]: 0x40 Core, 0x20 Atom; 0 = not seen yet
static mach_vm_address_t orgSetRatio;

// ─── HWP request ─────────────────────────────────────────────────────────────────────────────────────────────────
static uint64_t setRatio(uint64_t ratio, uint64_t a1, uint64_t a2, uint64_t a3) {   // Apple uses only edi
	const uint64_t r = FunctionCast(setRatio, orgSetRatio)(ratio, a1, a2, a3);
	if (!enabled || !(rdmsr64(0x770) & 1)) return r;
	const int cpu = cpuNumber();
	if (cpu < 0 || cpu >= MaxCpus) return r;
	if (!coreType[cpu]) coreType[cpu] = (uint8_t)(cpuidEax(0x1A) >> 24);
	const uint64_t v = rdmsr64(0x774);
	if (v & (1ULL << 42)) return r;   // package-level control: not used by XCPM on these CPUs
	uint64_t nv = v;
	if (hwpOn && coreType[cpu] == 0x40) {
		// max -> the core's highest (the turbo ratio table still applies), desired -> HWP units
		const uint32_t hi = (uint32_t)rdmsr64(0x771) & 0xff, max = (uint32_t)(v >> 8) & 0xff, des = (uint32_t)(v >> 16) & 0xff;
		auto toHwp = [&](uint32_t ratio) { uint32_t p = (ratio * 100000 + HybridScale / 2) / HybridScale; return p > hi ? hi : p; };
		if (max && hi > max)
			nv = (nv & ~0xFFFF00ULL) | ((uint64_t)hi << 8) | ((uint64_t)(des ? toHwp(des) : 0) << 16);
	}
	if (autonomous) nv &= ~0xFF0000ULL;
	if (eppOverride >= 0) nv = (nv & ~0xFF000000ULL) | ((uint64_t)eppOverride << 24);
	if (nv != v) wrmsr64(0x774, nv);
	return r;
}

// ─── energy-efficient turbo ──────────────────────────────────────────────────────────────────────────────────────
static void eetOne(void *on) {
	const uint64_t v = rdmsr64(0x1FC), want = on ? (v | (1ULL << 19)) : (v & ~(1ULL << 19));
	if (want != v) wrmsr64(0x1FC, want);
}

static void apply(thread_call_param_t, thread_call_param_t) {
	rendezvous(eetOne, eetOff ? (void *)1 : nullptr);
	enabled = orgSetRatio != 0;   // the request is converted at XCPM's next write on each CPU
	applied = 1;
	SYSLOG("hpm", "on: route %d, hwp %d, autonomous %d, epp %d, eet_off %d", route, hwpOn, autonomous, eppOverride, (int)((rdmsr64(0x1FC) >> 19) & 1));
}

// ─── state for hpmstat ───────────────────────────────────────────────────────────────────────────────────────────
struct HpmCpu { uint64_t aperf, mperf, hwpReq, hwpCap; uint8_t type, temp, pad[6]; };
struct HpmState {
	uint32_t version, ncpu, tjmax, pkgTemp;
	uint64_t tsc, pkgEnergy, iaEnergy, gtEnergy, raplUnit, pkgPowerLimit, mchPowerLimit, perfLimitReasons, powerCtl,
	         turboRatio, turboRatioCores, platformInfo;
	HpmCpu cpu[MaxCpus];
};
static HpmState state;
static IOMemoryMap *mchMap;

static void sampleOne(void *) {
	const int c = cpuNumber();
	if (c < 0 || c >= MaxCpus) return;
	auto &s = state.cpu[c];
	s.aperf = rdmsr64(0xE8);
	s.mperf = rdmsr64(0xE7);
	if (rdmsr64(0x770) & 1) { s.hwpReq = rdmsr64(0x774); s.hwpCap = rdmsr64(0x771); }
	s.type = (uint8_t)(cpuidEax(0x1A) >> 24);
	const uint32_t tj = (uint32_t)(rdmsr64(0x1A2) >> 16) & 0xff, dro = (uint32_t)(rdmsr64(0x19C) >> 16) & 0x7f;
	s.temp = (uint8_t)(tj > dro ? tj - dro : 0);
	__sync_fetch_and_add(&state.ncpu, 1);
}

static void mapMchbar() {
	OSIterator *it = IOService::getMatchingServices(IOService::serviceMatching("IOPCIDevice"));
	if (!it) return;
	uint64_t mch = 0;
	while (auto *o = it->getNextObject()) {
		auto *d = OSDynamicCast(IOPCIDevice, o);
		if (d && !d->getBusNumber() && !d->getDeviceNumber() && !d->getFunctionNumber()) {
			const uint64_t v = ((uint64_t)d->configRead32(0x4C) << 32) | d->configRead32(0x48);
			if (v & 1) mch = v & 0x7FFFFE0000ULL;
			break;
		}
	}
	it->release();
	if (!mch) return;
	if (auto *md = IOMemoryDescriptor::withPhysicalAddress(mch + 0x5000, 0x1000, kIODirectionIn)) {
		mchMap = md->createMappingInTask(kernel_task, 0, kIOMapAnywhere | kIOMapInhibitCache | kIOMapReadOnly);
		md->release();
	}
}

static int stateHandler SYSCTL_HANDLER_ARGS {
	if (!rendezvous || !cpuNumber) return ENODEV;
	bzero(&state, sizeof(state));
	state.version = 1;
	rendezvous(sampleOne, nullptr);
	state.tsc = __builtin_ia32_rdtsc();
	state.tjmax = (uint32_t)(rdmsr64(0x1A2) >> 16) & 0xff;
	const uint32_t pd = (uint32_t)(rdmsr64(0x1B1) >> 16) & 0x7f;
	state.pkgTemp = state.tjmax > pd ? state.tjmax - pd : 0;
	state.raplUnit = rdmsr64(0x606);
	state.pkgEnergy = rdmsr64(0x611) & 0xffffffff;
	state.iaEnergy = rdmsr64(0x639) & 0xffffffff;
	state.gtEnergy = rdmsr64(0x641) & 0xffffffff;
	state.pkgPowerLimit = rdmsr64(0x610);
	state.perfLimitReasons = rdmsr64(0x64F);
	state.powerCtl = rdmsr64(0x1FC);
	state.turboRatio = rdmsr64(0x1AD);
	state.turboRatioCores = rdmsr64(0x1AE);
	state.platformInfo = rdmsr64(0xCE);
	if (mchMap) {
		auto *p = reinterpret_cast<volatile uint32_t *>(mchMap->getVirtualAddress() + 0x9A0);
		state.mchPowerLimit = ((uint64_t)p[1] << 32) | p[0];
	}
	return SYSCTL_OUT(req, &state, sizeof(state));
}

static int eetHandler SYSCTL_HANDLER_ARGS {
	int v = eetOff;
	int err = SYSCTL_OUT(req, &v, sizeof(v));
	if (err || !req->newptr) return err;
	if ((err = SYSCTL_IN(req, &v, sizeof(v)))) return err;
	eetOff = v != 0;
	if (applied) rendezvous(eetOne, eetOff ? (void *)1 : nullptr);
	return 0;
}

SYSCTL_NODE(_debug, OID_AUTO, hybridpm, CTLFLAG_RW, 0, "HybridPM");
SYSCTL_PROC(_debug_hybridpm, OID_AUTO, state, CTLTYPE_OPAQUE | CTLFLAG_RD | CTLFLAG_ANYBODY, nullptr, 0, stateHandler, "S", "MSR sample");
SYSCTL_INT(_debug_hybridpm, OID_AUTO, hwp, CTLFLAG_RW, &hwpOn, 0, "convert XCPM ratios to HWP units on P-cores");
SYSCTL_INT(_debug_hybridpm, OID_AUTO, autonomous, CTLFLAG_RW, &autonomous, 0, "1 = desired 0, the hardware picks the clock");
SYSCTL_INT(_debug_hybridpm, OID_AUTO, epp, CTLFLAG_RW, &eppOverride, 0, "EPP override, -1 keeps XCPM's");
SYSCTL_PROC(_debug_hybridpm, OID_AUTO, eet_off, CTLTYPE_INT | CTLFLAG_RW, nullptr, 0, eetHandler, "I", "1 = energy-efficient turbo off");
SYSCTL_INT(_debug_hybridpm, OID_AUTO, route, CTLFLAG_RD, &route, 0, "1 routed, 2 no symbol, 3 no match, 4 route failed");
SYSCTL_INT(_debug_hybridpm, OID_AUTO, enabled, CTLFLAG_RD, &enabled, 0, "");

// The routine builds the request from its ratio argument (edi) and writes it: prologue, then at +0x168
// "mov eax,edi; shr edx,0x18; mov ecx,0x774; wrmsr". Search forward from the exported neighbour for exactly one match.
static void processKernel(KernelPatcher &patcher) {
	rendezvous = reinterpret_cast<RendezvousFn>(patcher.solveSymbol(KernelPatcher::KernelID, "_mp_rendezvous_no_intrs"));
	cpuNumber = reinterpret_cast<CpuNumberFn>(patcher.solveSymbol(KernelPatcher::KernelID, "_cpu_number"));
	const mach_vm_address_t base = patcher.solveSymbol(KernelPatcher::KernelID, "_xcpm_enable_pstate_ctrs");
	patcher.clearError();
	if (!rendezvous || !cpuNumber || !base) { route = 2; return; }
	static const uint8_t pro[] = {0x55, 0x48, 0x89, 0xE5, 0x53, 0x50, 0x89, 0xFB};
	static const uint8_t wr[] = {0x89, 0xF8, 0xC1, 0xEA, 0x18, 0xB9, 0x74, 0x07, 0x00, 0x00, 0x0F, 0x30};
	mach_vm_address_t fn = 0;
	int matches = 0;
	for (mach_vm_address_t a = base; a < base + 0x2000; a++) {
		if (memcmp(reinterpret_cast<const void *>(a), pro, sizeof(pro)) || memcmp(reinterpret_cast<const void *>(a + 0x168), wr, sizeof(wr))) continue;
		fn = a;
		matches++;
	}
	if (matches != 1) { route = 3; return; }
	orgSetRatio = patcher.routeFunction(fn, reinterpret_cast<mach_vm_address_t>(setRatio), true);
	if (patcher.getError() != KernelPatcher::Error::NoError) { orgSetRatio = 0; patcher.clearError(); route = 4; return; }
	route = 1;
	DBGLOG("hpm", "routed _xcpm_enable_pstate_ctrs+0x%llx", fn - base);
	mapMchbar();
	sysctl_register_oid(&sysctl__debug_hybridpm_hwp);
	sysctl_register_oid(&sysctl__debug_hybridpm_autonomous);
	sysctl_register_oid(&sysctl__debug_hybridpm_epp);
	sysctl_register_oid(&sysctl__debug_hybridpm_eet_off);
	uint64_t deadline;
	if (thread_call_t t = thread_call_allocate(apply, nullptr)) {
		clock_interval_to_deadline(20, kSecondScale, &deadline);
		thread_call_enter_delayed(t, deadline);
	}
}

static const char *bootargOff[] {"-hpmoff"};
static const char *bootargDebug[] {"-hpmdbg"};
static const char *bootargBeta[] {"-hpmbeta"};

PluginConfiguration ADDPR(config) {
	xStringify(PRODUCT_NAME),
	parseModuleVersion(xStringify(MODULE_VERSION)),
	LiluAPI::AllowNormal,
	bootargOff, arrsize(bootargOff),
	bootargDebug, arrsize(bootargDebug),
	bootargBeta, arrsize(bootargBeta),
	KernelVersion::BigSur,
	KernelVersion::Tahoe,
	[]() {
		int v;
		if (PE_parse_boot_argn("hpmhwp", &v, sizeof(v))) hwpOn = v != 0;
		if (PE_parse_boot_argn("hpmauto", &v, sizeof(v))) autonomous = v != 0;
		if (PE_parse_boot_argn("hpmepp", &v, sizeof(v)) && v >= -1 && v <= 255) eppOverride = v;
		if (PE_parse_boot_argn("hpmeet", &v, sizeof(v))) eetOff = v != 0;
		sysctl_register_oid(&sysctl__debug_hybridpm);
		sysctl_register_oid(&sysctl__debug_hybridpm_state);
		sysctl_register_oid(&sysctl__debug_hybridpm_route);
		sysctl_register_oid(&sysctl__debug_hybridpm_enabled);
		lilu.onPatcherLoadForce([](void *, KernelPatcher &patcher) { processKernel(patcher); });
	}
};

// Match Xcode's kext lifecycle: libkmod forwards start/stop through _realmain and _antimain.
extern "C" {
extern kern_return_t _start(kmod_info_t *, void *);
extern kern_return_t _stop(kmod_info_t *, void *);
extern kern_return_t HybridPM_kern_start(kmod_info_t *, void *);
extern kern_return_t HybridPM_kern_stop(kmod_info_t *, void *);
__attribute__((visibility("default"))) KMOD_EXPLICIT_DECL(io.github.yusufklncc.HybridPM, xStringify(MODULE_VERSION), _start, _stop)
__attribute__((visibility("hidden"))) kmod_start_func_t *_realmain = HybridPM_kern_start;
__attribute__((visibility("hidden"))) kmod_stop_func_t *_antimain = HybridPM_kern_stop;
__attribute__((visibility("hidden"))) int _kext_apple_cc = __APPLE_CC__;
}
