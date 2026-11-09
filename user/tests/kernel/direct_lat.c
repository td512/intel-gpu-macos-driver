// SPDX-License-Identifier: MIT
// direct_lat: what a tiny job costs through DRM_IOCTL_XE_EXEC on a compute queue with DRM_XE_EXEC_QUEUE_LOW_LATENCY_HINT,
// the queue kind the kext's direct submission (debug.intelxe.direct, xe_core.cpp) takes. Run it with direct=0 and 1:
// the same exec path, with the job going to the GuC (SCHED_CONTEXT) or into an armed ring slot (mailbox).
// Per CPU gap between jobs (0, 20 us, 100 us, 1 ms, 5 ms; the kext leaves direct mode after debug.intelxe.direct_idle_us,
// 2 ms by default, so 5 ms measures the way back in):
//   store:  exec ioctl -> the batch's MI_STORE_DATA_IMM visible to a spinning CPU (then the syncobj wait, untimed)
//   signal: exec ioctl -> DRM_IOCTL_SYNCOBJ_WAIT returning (the waiter sleeps at once, as Metal's does)
// Then two correctness checks: a burst of jobs submitted back to back while the first runs (each needs its own armed
// slot), and a compute job whose in-fence is a render job's, which waits in the FIFO (the kext leaves direct mode
// first). The direct-submission counters of debug.intelxe.stats are printed before and after.
// No Mesa, no Metal plugin. Measurement and checks only.
//   clang -arch x86_64 -O2 -I../../../kernel/IntelXe/uapi -o direct_lat direct_lat.c -framework IOKit
//   ./direct_lat [jobs]
#include <IOKit/IOKitLib.h>
#include <errno.h>
#include <immintrin.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include "xe_drm.h"

static io_connect_t conn;
static int xioctl(unsigned long req, void *arg) {
	uint64_t in[2] = {req, (uint64_t)(uintptr_t)arg}, out = 0;
	uint32_t n = 1;
	if (IOConnectCallScalarMethod(conn, 0, in, 2, &out, &n)) return -1;
	errno = (int)out;
	return out ? -1 : 0;
}
static mach_timebase_info_data_t tb;
static uint64_t ns(void) { return mach_absolute_time() * tb.numer / tb.denom; }
static int dcmp(const void *a, const void *b) { double x = *(const double *)a, y = *(const double *)b; return x < y ? -1 : x > y; }
static uint32_t gem(uint64_t size) {
	struct drm_xe_gem_create g = {.size = size, .placement = 1, .cpu_caching = DRM_XE_GEM_CPU_CACHING_WB};
	if (xioctl(DRM_IOCTL_XE_GEM_CREATE, &g)) { fprintf(stderr, "GEM_CREATE %d\n", errno); exit(1); }
	return g.handle;
}
static void *map(uint32_t handle, uint64_t size) {
	struct drm_xe_gem_mmap_offset m = {.handle = handle};
	if (xioctl(DRM_IOCTL_XE_GEM_MMAP_OFFSET, &m)) return NULL;
	mach_vm_address_t addr = 0; mach_vm_size_t sz = size;
	if (IOConnectMapMemory64(conn, (uint32_t)(m.offset >> 12), mach_task_self(), &addr, &sz, kIOMapAnywhere)) return NULL;
	return (void *)(uintptr_t)addr;
}
static int bind(uint32_t vm, uint32_t bo, uint64_t addr, uint64_t range) {
	struct drm_xe_vm_bind b = {.vm_id = vm, .num_binds = 1};
	b.bind.obj = bo; b.bind.range = range; b.bind.addr = addr; b.bind.op = DRM_XE_VM_BIND_OP_MAP; b.bind.pat_index = 2;
	return xioctl(DRM_IOCTL_XE_VM_BIND, &b);
}
static void spin_ns(uint64_t d) { uint64_t t = ns(); while (ns() - t < d) __asm__ volatile("pause"); }
static void flush(volatile void *p, size_t len) {   // the CPU's writes out to memory before the GPU reads them
	for (size_t o = 0; o < len; o += 64) _mm_clflush((const char *)p + o);
	_mm_mfence();
}
static void st(const char *nm, double *v, int n) {
	qsort(v, n, 8, dcmp); double s = 0; for (int i = 0; i < n; i++) s += v[i];
	printf("    %-26s p50 %7.2f  p90 %7.2f  p99 %7.2f  mean %7.2f us\n", nm, v[n / 2], v[n * 9 / 10], v[n * 99 / 100], s / n);
}
static void directStats(const char *when) {   // the "direct submission" line of debug.intelxe.stats
	static char b[8192];
	size_t len = sizeof b;
	int on = -1, idle = -1;
	size_t il = sizeof on;
	sysctlbyname("debug.intelxe.direct", &on, &il, NULL, 0);
	il = sizeof idle;
	sysctlbyname("debug.intelxe.direct_idle_us", &idle, &il, NULL, 0);
	if (sysctlbyname("debug.intelxe.stats", b, &len, NULL, 0)) { printf("%s: debug.intelxe.stats unreadable\n", when); return; }
	char *l = strstr(b, "direct submission");
	char *e = l ? strchr(l, '\n') : NULL;
	if (e) *e = 0;
	printf("%s: direct=%d idle_us=%d | %s\n", when, on, idle, l ? l : "(no direct submission line: old kext)");
}

#define MI_SDI (0x20u << 23 | 2)   // MI_STORE_DATA_IMM, PPGTT, one dword
#define MI_BBE (0x0au << 23)       // MI_BATCH_BUFFER_END
enum { WORK = 0x400000, TARGET = 0x900000 };
enum { WORK_DW = 16, NBATCH = 256, BURST = 64 };

static uint32_t q, rq, so[BURST + 1];
static volatile uint32_t *work, *tg;
// batch k: store v to target dword t, end
static uint64_t batch(int k, uint32_t t, uint32_t v) {
	volatile uint32_t *b = work + (size_t)(k % NBATCH) * WORK_DW;
	b[0] = MI_SDI; b[1] = TARGET + t * 4; b[2] = 0; b[3] = v; b[4] = MI_BBE; b[5] = 0;
	flush(b, 32);
	return WORK + (uint64_t)(k % NBATCH) * WORK_DW * 4;
}
static int exec(uint32_t queue, uint64_t addr, uint32_t signal, uint32_t wait) {
	struct drm_xe_sync s[2] = {{.type = DRM_XE_SYNC_TYPE_SYNCOBJ, .flags = DRM_XE_SYNC_FLAG_SIGNAL, .handle = signal},
		{.type = DRM_XE_SYNC_TYPE_SYNCOBJ, .handle = wait}};
	struct drm_xe_exec x = {.exec_queue_id = queue, .num_syncs = wait ? 2 : 1, .syncs = (uint64_t)(uintptr_t)s, .address = addr,
		.num_batch_buffer = 1};
	return xioctl(DRM_IOCTL_XE_EXEC, &x);
}
static int wait1(uint32_t h) {
	struct drm_syncobj_wait w = {.handles = (uint64_t)(uintptr_t)&h, .count_handles = 1, .timeout_nsec = (int64_t)(ns() + 2000000000ull)};
	return xioctl(DRM_IOCTL_SYNCOBJ_WAIT, &w);
}
static uint32_t newQueue(uint32_t vm, uint16_t cls, uint32_t flags) {
	struct drm_xe_engine_class_instance ei = {.engine_class = cls};
	struct drm_xe_exec_queue_create c = {.width = 1, .num_placements = 1, .vm_id = vm, .flags = flags,
		.instances = (uint64_t)(uintptr_t)&ei};
	if (xioctl(DRM_IOCTL_XE_EXEC_QUEUE_CREATE, &c)) { fprintf(stderr, "queue class %u: %d\n", cls, errno); exit(1); }
	return c.exec_queue_id;
}

int main(int argc, char **argv) {
	mach_timebase_info(&tb);
	io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IntelXe"));
	if (!svc || IOServiceOpen(svc, mach_task_self(), 0, &conn)) { fprintf(stderr, "no IntelXe service\n"); return 1; }
	const int N = argc > 1 ? atoi(argv[1]) : 1000;
	if (N < 20) { fprintf(stderr, "jobs >= 20\n"); return 1; }
	const uint64_t gaps[] = {0, 20000, 100000, 1000000, 5000000};
	const int counts[] = {N, N, N, N / 5, N / 10};

	struct drm_xe_vm_create vc = {0};
	if (xioctl(DRM_IOCTL_XE_VM_CREATE, &vc)) { fprintf(stderr, "vm create %d\n", errno); return 1; }
	const uint64_t workSize = (NBATCH * WORK_DW * 4 + 0xffff) & ~0xffffull;
	uint32_t workBo = gem(workSize), tgBo = gem(0x1000);
	work = map(workBo, workSize);
	tg = map(tgBo, 0x1000);
	if (!work || !tg) { fprintf(stderr, "map\n"); return 1; }
	if (bind(vc.vm_id, workBo, WORK, workSize) || bind(vc.vm_id, tgBo, TARGET, 0x1000)) { fprintf(stderr, "bind %d\n", errno); return 1; }
	q = newQueue(vc.vm_id, DRM_XE_ENGINE_CLASS_COMPUTE, DRM_XE_EXEC_QUEUE_LOW_LATENCY_HINT);
	rq = newQueue(vc.vm_id, DRM_XE_ENGINE_CLASS_RENDER, 0);
	for (int i = 0; i <= BURST; i++) {
		struct drm_syncobj_create sc = {0};
		if (xioctl(DRM_IOCTL_SYNCOBJ_CREATE, &sc)) { fprintf(stderr, "syncobj %d\n", errno); return 1; }
		so[i] = sc.handle;
	}
	double *lat = calloc(N, 8);
	directStats("before");
	printf("direct_lat: compute queue with LOW_LATENCY_HINT, %d jobs per gap (1 ms: %d, 5 ms: %d)\n", N, N / 5, N / 10);

	uint32_t seq = 0x1000;
	int k = 0;
	for (int gi = 0; gi < 5; gi++) {
		const int n = counts[gi];
		printf("  gap %5llu us\n", gaps[gi] / 1000);
		for (int pass = 0; pass < 2; pass++) {
			for (int i = 0; i < n + 5; i++, k++) {
				seq++;
				const uint64_t a = batch(k, 0, seq);
				spin_ns(gaps[gi]);
				const uint64_t t0 = ns();
				if (exec(q, a, so[0], 0)) { printf("exec failed %d\n", errno); return 1; }
				uint64_t t1;
				if (pass == 0) {
					while (tg[0] != seq && ns() - t0 < 1000000000ull) __asm__ volatile("pause");
					t1 = ns();
					if (wait1(so[0])) { printf("wait failed %d (job %u)\n", errno, seq); return 1; }
				} else {
					if (wait1(so[0])) { printf("wait failed %d (job %u)\n", errno, seq); return 1; }
					t1 = ns();
				}
				if (tg[0] != seq) { printf("store missing: job %u, target 0x%x\n", seq, tg[0]); return 1; }
				if (i >= 5) lat[i - 5] = (t1 - t0) / 1e3;
			}
			st(pass ? "exec -> syncobj signaled" : "exec -> store visible", lat, n);
		}
	}
	directStats("after latency");

	// back to back: BURST jobs, each to its own dword and with its own syncobj, submitted without waiting; repeated
	int bad = 0;
	for (int r = 0; r < 20 && !bad; r++) {
		for (int i = 0; i < BURST; i++) tg[16 + i] = 0;
		flush(tg + 16, BURST * 4);
		for (int i = 0; i < BURST; i++, k++)
			if (exec(q, batch(k, 16 + i, 0xb0000000u | (uint32_t)(r << 8 | i)), so[1 + i], 0)) { printf("burst exec failed %d\n", errno); return 1; }
		for (int i = 0; i < BURST; i++)
			if (wait1(so[1 + i])) { printf("burst %d: job %d wait failed %d\n", r, i, errno); return 1; }
		for (int i = 0; i < BURST; i++)
			if (tg[16 + i] != (0xb0000000u | (uint32_t)(r << 8 | i))) { printf("burst %d: job %d stored 0x%x\n", r, i, tg[16 + i]); bad = 1; }
		spin_ns(r % 2 ? 3000000 : 50000);   // every other burst starts after the idle exit
	}
	printf("  back-to-back bursts of %d: %s\n", BURST, bad ? "FAILED" : "ok");

	// a compute job behind a render job's fence (it waits in the FIFO), between direct jobs
	bad = 0;
	for (int r = 0; r < 50 && !bad; r++) {
		for (int i = 0; i < 3; i++, k++) {   // direct jobs first (arm)
			seq++;
			if (exec(q, batch(k, 0, seq), so[0], 0) || wait1(so[0])) { printf("fifo: compute exec/wait failed %d\n", errno); return 1; }
		}
		tg[1] = tg[2] = 0;
		flush(tg, 64);
		const uint32_t rv = 0xc0000000u | (uint32_t)r, cv = 0xd0000000u | (uint32_t)r;
		if (exec(rq, batch(k++, 1, rv), so[1], 0)) { printf("fifo: render exec failed %d\n", errno); return 1; }
		if (exec(q, batch(k++, 2, cv), so[2], so[1])) { printf("fifo: compute exec failed %d\n", errno); return 1; }
		if (wait1(so[2])) { printf("fifo %d: compute wait failed %d\n", r, errno); return 1; }
		if (tg[1] != rv || tg[2] != cv) { printf("fifo %d: render 0x%x compute 0x%x\n", r, tg[1], tg[2]); bad = 1; }
	}
	printf("  compute job behind a render fence: %s\n", bad ? "FAILED" : "ok");
	directStats("after checks");

	struct drm_xe_exec_queue_destroy d = {.exec_queue_id = q};
	xioctl(DRM_IOCTL_XE_EXEC_QUEUE_DESTROY, &d);
	d.exec_queue_id = rq;
	xioctl(DRM_IOCTL_XE_EXEC_QUEUE_DESTROY, &d);
	return 0;
}
