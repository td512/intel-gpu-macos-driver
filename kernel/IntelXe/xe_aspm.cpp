// SPDX-License-Identifier: MIT
// PCIe ASPM on the GPU's path to the CPU (experimental, off unless asked for; untested on hardware).
//
//   sysctl debug.intelxe.aspm          (anyone) every link between the GPU function and its root port: Link Capabilities,
//                                      Link Control, Link Status, Device Capabilities, L1 PM Substates, the L1 checks
//                                      and the last change made
//   sudo sysctl debug.intelxe.aspm_l1=1   L1 on every link of the path, if every check passes (else nothing changes)
//   sudo sysctl debug.intelxe.aspm_l1=0   ASPM (L0s and L1) off on every link of the path
//   sudo sysctl debug.intelxe.aspm_l1=-1  (default) leave the links alone from now on (what was changed stays until a
//                                      reboot, or until 0 is written)
// After a system wake the last 0 or 1 written is applied again where the links no longer match it.
//
// The path: the B580 sits behind a switch on the card (upstream port 8086:e2ff, a downstream port 8086:e2f0 per
// function group) under a CPU or PCH root port, so it has two links: downstream port <-> GPU and root port <-> upstream
// port. In the service plane every IOPCIDevice's provider is the bridge driver (IOPCI2PCIBridge) of the port above it,
// whose provider is that port's IOPCIDevice; the walk stops at the host bridge, which is no IOPCIDevice.
//
// Changes go only through IOPCIDevice::setASPMState(client, state), called on each function of the downstream end of a
// link: IOPCIDevice.cpp passes it to its parent IOPCI2PCIBridge::setDeviceASPMState (IOPCIBridge.cpp), which writes the
// Link Control ASPM bits of both ends of exactly that link (the device and the bridge's own IOPCIDevice, fBridgeDevice),
// enable upstream first and disable downstream first, masked with what both ends advertise, and records the value in
// both ends' "pci-aspm-default". IOPCIFamily keeps Link Control in the config space it saves at sleep and restores at
// wake, so it holds without us; the wake path here only checks it. No direct Link Control write is needed: both links
// have an IOPCI2PCIBridge above their downstream end. Side effect of that call on function 0: the L1 PM Substates
// Control 1/2 registers of both ends are rewritten, to 0 unless the device tree gives "pci-l1ss-enable" or
// "pci-l1pm-control" (setDeviceL1PMBits), so L1 substates the firmware had enabled on a link we change are switched off.
// Links already in the requested state are not touched (xeAspmPlan).
#include "IntelXe.h"
#include "xe_aspm.h"
#include <IOKit/IORegistryEntry.h>
#include <sys/sysctl.h>

extern IntelXe *gDev;
IOLock *gAspmLock;     // allocated with the kext's other locks (IntelXe_start)
int gAspmL1 = -1;      // debug.intelxe.aspm_l1
static char gAspmLast[1024] = "none";

namespace {

struct AspmPath {
	XeAspmLink links[XE_ASPM_MAX_LINKS];
	IOPCIDevice *upDev[XE_ASPM_MAX_LINKS];
	IOPCIDevice *downDev[XE_ASPM_MAX_LINKS][XE_ASPM_MAX_FN];
	char bridgeClass[XE_ASPM_MAX_LINKS][48];   // the driver above each link's downstream end (setASPMState needs IOPCI2PCIBridge)
	uint32_t nLinks;
	XeAspmEndpoint eps[XE_ASPM_MAX_EPS];
	uint32_t nEps;
	bool tooMany;
	char err[128];
};

void readFn(IOPCIDevice *d, XeAspmFn *f) {
	bzero(f, sizeof *f);
	f->vendor = d->configRead16((UInt8)kIOPCIConfigVendorID);
	f->device = d->configRead16((UInt8)kIOPCIConfigDeviceID);
	f->bus = d->getBusNumber();
	f->dev = d->getDeviceNumber();
	f->fn = d->getFunctionNumber();
	if (f->vendor == 0xffff) return;
	UInt8 off = 0;
	if (!d->findPCICapability(kIOPCIPCIExpressCapability, &off) || !off) return;
	f->pcie = true;
	f->type = (uint8_t)(d->configRead16((UInt8)(off + XE_PCIE_FLAGS)) >> 4 & 0xf);
	f->devCap = d->configRead32((UInt8)(off + XE_PCIE_DEVCAP));
	f->lnkCap = d->configRead32((UInt8)(off + XE_PCIE_LNKCAP));
	f->lnkCtl = d->configRead16((UInt8)(off + XE_PCIE_LNKCTL));
	f->lnkSta = d->configRead16((UInt8)(off + XE_PCIE_LNKSTA));
	IOByteCount x = 0;
	if (d->extendedFindPCICapability((UInt32)-(int32_t)XE_PCIE_EXT_CAP_L1SS, &x) && x) {
		f->l1ss = true;
		f->l1ssCap = d->extendedConfigRead32(x + XE_L1SS_CAP);
		f->l1ssCtl1 = d->extendedConfigRead32(x + XE_L1SS_CTL1);
		f->l1ssCtl2 = d->extendedConfigRead32(x + XE_L1SS_CTL2);
	}
}

uint8_t pcieType(IOPCIDevice *d) {
	UInt8 off = 0;
	if (!d->findPCICapability(kIOPCIPCIExpressCapability, &off) || !off) return 0xff;
	return (uint8_t)(d->configRead16((UInt8)(off + XE_PCIE_FLAGS)) >> 4 & 0xf);
}

// The port above `d` (nullptr at the host bridge), and the bridge driver in between
IOPCIDevice *pciUp(IOPCIDevice *d, IORegistryEntry **bridge = nullptr) {
	IORegistryEntry *b = d->getParentEntry(gIOServicePlane);
	if (!b || OSDynamicCast(IOPCIDevice, b)) return nullptr;
	if (bridge) *bridge = b;
	return OSDynamicCast(IOPCIDevice, b->getParentEntry(gIOServicePlane));
}

// Every function of `d`'s device on its bus (the bridge's children with d's device number), function 0 first.
uint32_t siblingFunctions(IORegistryEntry *bridge, IOPCIDevice *d, IOPCIDevice **out, bool *tooMany) {
	uint32_t n = 0;
	if (OSIterator *it = bridge->getChildIterator(gIOServicePlane)) {
		while (OSObject *o = it->getNextObject()) {
			IOPCIDevice *c = OSDynamicCast(IOPCIDevice, o);
			if (!c || c->getBusNumber() != d->getBusNumber() || c->getDeviceNumber() != d->getDeviceNumber()) continue;
			if (n == XE_ASPM_MAX_FN) { *tooMany = true; break; }
			out[n++] = c;
		}
		it->release();
	}
	if (!n) out[n++] = d;
	for (uint32_t i = 1; i < n; i++)   // by function number
		for (uint32_t j = i; j > 0 && out[j]->getFunctionNumber() < out[j - 1]->getFunctionNumber(); j--) {
			IOPCIDevice *t = out[j];
			out[j] = out[j - 1];
			out[j - 1] = t;
		}
	return n;
}

// The lowest path link above endpoint `e` and the links between them; false if its path does not reach one.
bool endpointPlace(const AspmPath &p, IOPCIDevice *e, uint32_t *link, uint32_t *hops) {
	IOPCIDevice *d = e;
	uint32_t h = 0;
	for (int depth = 0; depth < 8; depth++) {
		IOPCIDevice *u = pciUp(d);
		if (!u) return false;
		const uint8_t ut = pcieType(u), dt = pcieType(d);
		if (xeAspmIsLink(ut, dt)) {
			for (uint32_t k = 0; k < p.nLinks; k++)
				if (p.upDev[k] == u) {
					*link = k;
					*hops = h;
					return true;
				}
			h++;
		}
		d = u;
	}
	return false;
}

void addEndpoint(AspmPath &p, IOPCIDevice *e) {
	XeAspmFn f;
	readFn(e, &f);
	if (!f.pcie || !xeAspmIsEndpoint(f.type)) return;
	for (uint32_t i = 0; i < p.nEps; i++)
		if (p.eps[i].bus == f.bus && p.eps[i].dev == f.dev && p.eps[i].fn == f.fn) return;
	uint32_t link = 0, hops = 0;
	if (!endpointPlace(p, e, &link, &hops)) return;
	if (p.nEps == XE_ASPM_MAX_EPS) {
		p.tooMany = true;
		return;
	}
	p.eps[p.nEps++] = XeAspmEndpoint{f.vendor, f.device, f.bus, f.dev, f.fn, f.devCap, link, hops};
}

// The links from `gpu` to its root port (link 0 = the GPU's own), and every endpoint below the top link. false (with
// p.err) when there is no link at all.
bool buildPath(IOPCIDevice *gpu, AspmPath &p) {
	bzero(&p, sizeof p);
	IOPCIDevice *d = gpu;
	for (int depth = 0; depth < 8 && p.nLinks < XE_ASPM_MAX_LINKS; depth++) {
		IORegistryEntry *bridge = nullptr;
		IOPCIDevice *u = pciUp(d, &bridge);
		if (!u) break;
		if (xeAspmIsLink(pcieType(u), pcieType(d))) {
			const uint32_t k = p.nLinks++;
			p.upDev[k] = u;
			readFn(u, &p.links[k].up);
			strlcpy(p.bridgeClass[k], bridge->getMetaClass()->getClassName(), sizeof p.bridgeClass[k]);
			p.links[k].nDown = siblingFunctions(bridge, d, p.downDev[k], &p.tooMany);
			for (uint32_t i = 0; i < p.links[k].nDown; i++) readFn(p.downDev[k][i], &p.links[k].down[i]);
			if (pcieType(u) == XE_PCIE_ROOT_PORT) break;
		}
		d = u;
	}
	if (!p.nLinks) {
		snprintf(p.err, sizeof p.err, "no PCIe link found above the GPU");
		return false;
	}
	// Endpoints: each function of the top link's downstream end and everything below it (the GPU among them)
	const uint32_t top = p.nLinks - 1;
	for (uint32_t i = 0; i < p.links[top].nDown; i++) {
		IOPCIDevice *t = p.downDev[top][i];
		addEndpoint(p, t);
		if (IORegistryIterator *it = IORegistryIterator::iterateOver(t, gIOServicePlane, kIORegistryIterateRecursively)) {
			while (IORegistryEntry *o = it->getNextObject())
				if (IOPCIDevice *e = OSDynamicCast(IOPCIDevice, o)) addEndpoint(p, e);
			it->release();
		}
	}
	return true;
}

void rereadPath(AspmPath &p) {
	for (uint32_t k = 0; k < p.nLinks; k++) {
		readFn(p.upDev[k], &p.links[k].up);
		for (uint32_t i = 0; i < p.links[k].nDown; i++) readFn(p.downDev[k][i], &p.links[k].down[i]);
	}
}

void lastf(size_t *n, const char *fmt, ...) __printflike(2, 3);
void lastf(size_t *n, const char *fmt, ...) {
	if (*n >= sizeof gAspmLast - 1) return;
	va_list ap;
	va_start(ap, fmt);
	const int k = vsnprintf(gAspmLast + *n, sizeof gAspmLast - *n, fmt, ap);
	va_end(ap);
	if (k > 0) *n = *n + (size_t)k < sizeof gAspmLast - 1 ? *n + (size_t)k : sizeof gAspmLast - 1;
}

// Take the path to `target` (0 or 1). gAspmLock held. 0 or an errno; what happened goes to gAspmLast and the log.
int aspmApply(int target, const char *why) {
	size_t n = 0;
	gAspmLast[0] = 0;
	if (!gDev || !gDev->pciDevice()) return ENODEV;
	if (gDev->pwrSuspendSent || gDev->suspended) {
		lastf(&n, "%s: aspm_l1=%d not applied: the device is asleep\n", why, target);
		return EBUSY;
	}
	AspmPath *p = static_cast<AspmPath *>(IOMalloc(sizeof(AspmPath)));
	if (!p) return ENOMEM;
	int err = 0;
	if (!buildPath(gDev->pciDevice(), *p)) {
		lastf(&n, "%s: aspm_l1=%d refused: %s\n", why, target, p->err);
		LOG("ASPM: aspm_l1=%d refused: %s", target, p->err);
		err = ENODEV;
		goto out;
	}
	for (uint32_t k = 0; k < p->nLinks; k++)
		if (strncmp(p->bridgeClass[k], "IOPCI2PCIBridge", sizeof p->bridgeClass[k])) {
			// IOPCIDevice::setASPMState answers kIOReturnUnsupported unless the parent is an IOPCI2PCIBridge (subclasses
			// keep its setDeviceASPMState); report the class so a different driver shows up here, then let the call decide.
			lastf(&n, "%s: note: link %u's bridge driver is %s\n", why, k, p->bridgeClass[k]);
		}
	if (target == 1) {
		if (p->tooMany) {
			lastf(&n, "%s: aspm_l1=1 refused: %s\n", why, xeAspmWhyName(XE_ASPM_TOO_MANY));
			LOG("ASPM: aspm_l1=1 refused: %s", xeAspmWhyName(XE_ASPM_TOO_MANY));
			err = EPERM;
			goto out;
		}
		for (uint32_t k = 0; k < p->nLinks; k++) {
			const XeAspmVerdict v = xeAspmL1Check(p->links, p->nLinks, k, p->eps, p->nEps);
			if (v.why != XE_ASPM_OK) {
				const XeAspmLink &l = p->links[k];
				lastf(&n, "%s: aspm_l1=1 refused, nothing changed: link %u (%04x:%04x <-> %04x:%04x): %s", why, k,
					l.up.vendor, l.up.device, l.down[0].vendor, l.down[0].device, xeAspmWhyName(v.why));
				if (v.why == XE_ASPM_LATENCY)
					lastf(&n, " (%04x:%04x accepts %u ns, the link gives %u ns)", p->eps[v.index].vendor,
						p->eps[v.index].device, v.acceptableNs, v.latencyNs);
				lastf(&n, "\n");
				LOG("ASPM: aspm_l1=1 refused: link %u (%04x:%04x <-> %04x:%04x): %s", k, l.up.vendor, l.up.device,
					l.down[0].vendor, l.down[0].device, xeAspmWhyName(v.why));
				err = EPERM;
				goto out;
			}
		}
	}
	{
		XeAspmStep steps[XE_ASPM_MAX_LINKS * XE_ASPM_MAX_FN * 2];
		const uint32_t ns = xeAspmPlan(p->links, p->nLinks, target, steps, sizeof steps / sizeof steps[0]);
		uint16_t before[XE_ASPM_MAX_LINKS][2];
		for (uint32_t k = 0; k < p->nLinks; k++) before[k][0] = p->links[k].up.lnkCtl, before[k][1] = p->links[k].down[0].lnkCtl;
		if (!ns) {
			lastf(&n, "%s: aspm_l1=%d: every link already %s, nothing written\n", why, target, target ? "has L1" : "has ASPM off");
			goto out;
		}
		for (uint32_t s = 0; s < ns; s++) {
			IOPCIDevice *d = p->downDev[steps[s].link][steps[s].fn];
			const IOReturn r = d->setASPMState(gDev, steps[s].state);
			LOG("ASPM: link %u: setASPMState(%02x:%02x.%x, %s) = 0x%x", steps[s].link, d->getBusNumber(),
				d->getDeviceNumber(), d->getFunctionNumber(), xeAspmCtlName(steps[s].state), r);
			if (r != kIOReturnSuccess) {
				lastf(&n, "%s: aspm_l1=%d stopped: setASPMState on %02x:%02x.%x (link %u, %s) returned 0x%x after %u of %u calls\n",
					why, target, d->getBusNumber(), d->getDeviceNumber(), d->getFunctionNumber(), steps[s].link,
					xeAspmCtlName(steps[s].state), r, s, ns);
				err = EIO;
				break;
			}
		}
		rereadPath(*p);
		if (!err) lastf(&n, "%s: aspm_l1=%d: %u setASPMState call(s)\n", why, target, ns);
		for (uint32_t k = 0; k < p->nLinks; k++) {
			const XeAspmLink &l = p->links[k];
			const int st = xeAspmLinkState(l);
			const bool ok = target == 1 ? st >= 0 && (st & XE_LNKCTL_ASPM_L1) : st == 0;
			lastf(&n, "  link %u: up LnkCtl 0x%04x -> 0x%04x, down LnkCtl 0x%04x -> 0x%04x: %s%s\n", k, before[k][0],
				l.up.lnkCtl, before[k][1], l.down[0].lnkCtl, st >= 0 ? xeAspmCtlName((uint32_t)st) : "ends differ",
				ok ? "" : " (NOT as asked)");
			LOG("ASPM: link %u: LnkCtl up 0x%04x -> 0x%04x, down 0x%04x -> 0x%04x%s", k, before[k][0], l.up.lnkCtl,
				before[k][1], l.down[0].lnkCtl, ok ? "" : " (not as asked)");
			if (!ok && !err) err = EIO;
		}
	}
out:
	IOFree(p, sizeof(AspmPath));
	return err;
}

}   // namespace

// debug.intelxe.aspm_l1 write
int xeAspmSet(int v) {
	if (v < -1 || v > 1) return EINVAL;
	if (!gAspmLock) return ENODEV;
	IOLockLock(gAspmLock);
	int err = 0;
	if (v == -1) {
		size_t n = 0;
		gAspmLast[0] = 0;
		lastf(&n, "sysctl: aspm_l1=-1: the links are left as they are now (a reboot gives the firmware's settings back)\n");
		gAspmL1 = -1;
	} else if (!(err = aspmApply(v, "sysctl"))) {
		gAspmL1 = v;
	}
	IOLockUnlock(gAspmLock);
	return err;
}

// After a system wake (IntelXe::setPowerState): the last 0 or 1 again where IOPCIFamily's restore did not keep it.
void xeAspmWake() {
	if (!gAspmLock) return;
	IOLockLock(gAspmLock);
	if (gAspmL1 >= 0) {
		const int err = aspmApply(gAspmL1, "wake");
		if (err) LOG("ASPM: aspm_l1=%d after wake: %d", gAspmL1, err);
	}
	IOLockUnlock(gAspmLock);
}

// debug.intelxe.aspm
int xeAspmReport(char *b, size_t len) {
	size_t n = 0;
	char t[256];
	if (!gDev || !gDev->pciDevice()) return snprintf(b, len, "no device\n");
	if (gDev->pwrSuspendSent || gDev->suspended) return snprintf(b, len, "unavailable (asleep)\n");
	AspmPath *p = static_cast<AspmPath *>(IOMalloc(sizeof(AspmPath)));
	if (!p) return snprintf(b, len, "no memory\n");
	IOLockLock(gAspmLock);
	snprintf(t, sizeof t, "aspm_l1 = %d (%s); experimental, untested\n", gAspmL1,
		gAspmL1 < 0 ? "leave as the firmware set it" : gAspmL1 ? "L1 on the path" : "ASPM off on the path");
	xeAspmPut(b, len, &n, t);
	if (!buildPath(gDev->pciDevice(), *p)) {
		snprintf(t, sizeof t, "%s\n", p->err);
		xeAspmPut(b, len, &n, t);
	} else {
		for (uint32_t k = 0; k < p->nLinks; k++) {
			const XeAspmLink &l = p->links[k];
			const int st = xeAspmLinkState(l);
			snprintf(t, sizeof t, "link %u: %s <-> %s, ASPM %s, via %s\n", k, xeAspmTypeName(l.up.type),
				xeAspmTypeName(l.down[0].type), st >= 0 ? xeAspmCtlName((uint32_t)st) : "differs between the ends",
				p->bridgeClass[k]);
			xeAspmPut(b, len, &n, t);
			xeAspmFormatFn(b, len, &n, "up  ", l.up);
			for (uint32_t i = 0; i < l.nDown; i++) xeAspmFormatFn(b, len, &n, "down", l.down[i]);
			const XeAspmVerdict v = xeAspmL1Check(p->links, p->nLinks, k, p->eps, p->nEps);
			xeAspmFormatVerdict(b, len, &n, v, l, p->eps);
		}
		xeAspmPut(b, len, &n, "endpoints below the path (L1 acceptable latency, link above, links between):\n");
		for (uint32_t e = 0; e < p->nEps; e++) {
			char a[16];
			xeAspmNs(a, sizeof a, xeAspmL1AcceptableNs(p->eps[e].devCap), true);
			snprintf(t, sizeof t, "  %02x:%02x.%x %04x:%04x: %s, link %u, %u\n", p->eps[e].bus, p->eps[e].dev, p->eps[e].fn,
				p->eps[e].vendor, p->eps[e].device, a, p->eps[e].link, p->eps[e].hops);
			xeAspmPut(b, len, &n, t);
		}
		if (p->tooMany) xeAspmPut(b, len, &n, "  (more functions or endpoints than the tables hold: aspm_l1=1 refuses)\n");
	}
	xeAspmPut(b, len, &n, "last change:\n");
	xeAspmPut(b, len, &n, gAspmLast);
	if (n && b[n - 1] != '\n') xeAspmPut(b, len, &n, "\n");
	IOLockUnlock(gAspmLock);
	IOFree(p, sizeof(AspmPath));
	return (int)n;
}

static int aspmHandler SYSCTL_HANDLER_ARGS {
	constexpr size_t kLen = 8192;
	char *b = static_cast<char *>(IOMalloc(kLen));
	if (!b) return ENOMEM;
	const int n = xeAspmReport(b, kLen);
	const int err = SYSCTL_OUT(req, b, (size_t)(n > 0 ? (n < (int)kLen - 1 ? n : (int)kLen - 1) : 0) + 1);
	IOFree(b, kLen);
	return err;
}
static int aspmL1Handler SYSCTL_HANDLER_ARGS {
	int v = gAspmL1, err = sysctl_handle_int(oidp, &v, 0, req);
	if (err || !req->newptr) return err;
	return xeAspmSet(v);
}
SYSCTL_DECL(_debug_intelxe);
SYSCTL_PROC(_debug_intelxe, OID_AUTO, aspm, CTLTYPE_STRING | CTLFLAG_RD | CTLFLAG_ANYBODY, nullptr, 0, aspmHandler, "A",
	"experimental: PCIe ASPM state of every link between the GPU and its root port, the L1 checks, the last change");
SYSCTL_PROC(_debug_intelxe, OID_AUTO, aspm_l1, CTLTYPE_INT | CTLFLAG_RW, nullptr, 0, aspmL1Handler, "I",
	"experimental: 1 = ASPM L1 on the GPU's path if every check passes, 0 = ASPM off there, -1 = leave it (default)");
void xeAspmRegister(bool on) {
	if (on) {
		sysctl_register_oid(&sysctl__debug_intelxe_aspm);
		sysctl_register_oid(&sysctl__debug_intelxe_aspm_l1);
	} else {
		sysctl_unregister_oid(&sysctl__debug_intelxe_aspm_l1);
		sysctl_unregister_oid(&sysctl__debug_intelxe_aspm);
	}
}
