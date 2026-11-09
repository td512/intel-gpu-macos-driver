// SPDX-License-Identifier: MIT
// ulls: what a job's round trip costs when it does not go through the kernel and the GuC at all, against the same job
// through DRM_IOCTL_XE_EXEC (proof of concept for direct submission, as Intel's compute driver does it: "ULLS").
// No Mesa, no Metal plugin. On the compute engine (WindowServer composites on render), one exec queue:
//   exec:   per job an exec of a 2nd-level-sized batch (MI_STORE_DATA_IMM of a sequence number + MI_BATCH_BUFFER_END),
//           the CPU spinning until the store is visible (no syncobj wait in the timed part: the GPU's own latency).
//   direct: ONE exec of a persistent batch with a slot per job: MI_SEMAPHORE_WAIT (polling) until a mailbox dword in
//           system memory reaches the job's number, then MI_BATCH_BUFFER_START (second level) of that job's batch,
//           which stores the sequence number and returns. Submitting = the CPU writes the job's batch and the mailbox.
// Both timed from the CPU's "go" (exec ioctl / mailbox write) to the store being visible to a spinning CPU, with a
// CPU gap between jobs (0, 20, 100 us, 1 ms). The persistent batch ends after the last slot, well inside the job
// watchdog (debug.intelxe.job_timeout_ms). Measurement only.
// "chain" (3rd argument): each job's second-level batch is a stub that chains (MI_BATCH_BUFFER_START with the second
// level bit clear) to the batch that stores, as ANV's batches chain, and the persistent batch stores the job number to
// a second dword after the call returns: a kernel-side direct submission would call an application's chained batch at
// the second level, so its MI_BATCH_BUFFER_END has to come back to the persistent batch.
//   clang -arch x86_64 -O2 -I../../../kernel/IntelXe/uapi -o ulls ulls.c -framework IOKit
//   ./ulls [jobs] [compute|render] [chain]
#include <IOKit/IOKitLib.h>
#include <errno.h>
#include <immintrin.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
	printf("    %-30s p50 %7.2f  p90 %7.2f  p99 %7.2f  mean %7.2f us\n", nm, v[n / 2], v[n * 9 / 10], v[n * 99 / 100], s / n);
}

#define MI_SDI (0x20u << 23 | 2)                    // MI_STORE_DATA_IMM, PPGTT, one dword
#define MI_BBE (0x0au << 23)                        // MI_BATCH_BUFFER_END
#define MI_BBS2 (0x31u << 23 | 1u << 22 | 1u << 8 | 1)   // MI_BATCH_BUFFER_START, second level, PPGTT
#define MI_BBSC (0x31u << 23 | 1u << 8 | 1)             // MI_BATCH_BUFFER_START, chained (no level change), PPGTT
#define MI_SEMA_GTE_POLL (0x1cu << 23 | 1u << 15 | 1u << 12 | 3)   // MI_SEMAPHORE_WAIT, polling, SAD >= SDD, PPGTT
enum { RING = 0x100000, WORK = 0x400000, MBOX = 0x800000, TARGET = 0x900000 };
enum { SLOT_DW = 12, WORK_DW = 16 };

int main(int argc, char **argv) {
	mach_timebase_info(&tb);
	io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IntelXe"));
	if (!svc || IOServiceOpen(svc, mach_task_self(), 0, &conn)) { fprintf(stderr, "no IntelXe service\n"); return 1; }
	const int N = argc > 1 ? atoi(argv[1]) : 1000;
	const uint16_t cls = argc > 2 && !strcmp(argv[2], "render") ? DRM_XE_ENGINE_CLASS_RENDER : DRM_XE_ENGINE_CLASS_COMPUTE;
	const int chain = argc > 3 && !strcmp(argv[3], "chain");
	const uint64_t gaps[] = {0, 20000, 100000, 1000000};
	const uint64_t ringBytes = (uint64_t)(4 * N + 16) * SLOT_DW * 4, workBytes = (uint64_t)4 * N * WORK_DW * 4;
	const uint64_t ringSize = (ringBytes + 0xffff) & ~0xffffull, workSize = (workBytes + 0xffff) & ~0xffffull;

	struct drm_xe_vm_create vc = {0};
	if (xioctl(DRM_IOCTL_XE_VM_CREATE, &vc)) { fprintf(stderr, "vm create %d\n", errno); return 1; }
	uint32_t ringBo = gem(ringSize), workBo = gem(workSize), mboxBo = gem(0x1000), tgBo = gem(0x1000);
	volatile uint32_t *ring = map(ringBo, ringSize), *work = map(workBo, workSize), *mbox = map(mboxBo, 0x1000), *tg = map(tgBo, 0x1000);
	if (!ring || !work || !mbox || !tg) { fprintf(stderr, "map\n"); return 1; }
	if (bind(vc.vm_id, ringBo, RING, ringSize) || bind(vc.vm_id, workBo, WORK, workSize) || bind(vc.vm_id, mboxBo, MBOX, 0x1000) ||
		bind(vc.vm_id, tgBo, TARGET, 0x1000)) { fprintf(stderr, "bind %d\n", errno); return 1; }
	struct drm_xe_engine_class_instance ei = {.engine_class = cls};
	struct drm_xe_exec_queue_create q = {.width = 1, .num_placements = 1, .vm_id = vc.vm_id, .instances = (uint64_t)(uintptr_t)&ei};
	if (xioctl(DRM_IOCTL_XE_EXEC_QUEUE_CREATE, &q)) { fprintf(stderr, "queue %d\n", errno); return 1; }
	struct drm_syncobj_create sc = {0};
	xioctl(DRM_IOCTL_SYNCOBJ_CREATE, &sc);
	uint32_t h[1] = {sc.handle};
	double *lat = calloc(N, 8);
	printf("ulls on %s, %d jobs per gap%s\n", cls == DRM_XE_ENGINE_CLASS_COMPUTE ? "compute" : "render", N,
		chain ? ", chained second-level batches" : "");

	// 1. through the kernel: one exec per job, the CPU spinning on the store
	uint32_t seq = 0x1000;
	for (int gi = 0; gi < 4; gi++) {
		int n = gi == 3 ? N / 5 : N;
		for (int i = 0; i < n + 5; i++) {
			seq++;
			volatile uint32_t *b = work;
			b[0] = MI_SDI; b[1] = TARGET; b[2] = 0; b[3] = seq; b[4] = MI_BBE; b[5] = 0;
			flush(b, 32);
			spin_ns(gaps[gi]);
			struct drm_xe_sync s = {.type = DRM_XE_SYNC_TYPE_SYNCOBJ, .flags = DRM_XE_SYNC_FLAG_SIGNAL, .handle = sc.handle};
			struct drm_xe_exec x = {.exec_queue_id = q.exec_queue_id, .num_syncs = 1, .syncs = (uint64_t)(uintptr_t)&s, .address = WORK,
				.num_batch_buffer = 1};
			const uint64_t t0 = ns();
			if (xioctl(DRM_IOCTL_XE_EXEC, &x)) { printf("exec failed %d\n", errno); return 1; }
			while (tg[0] != seq && ns() - t0 < 1000000000ull) __asm__ volatile("pause");
			const uint64_t t1 = ns();
			struct drm_syncobj_wait w = {.handles = (uint64_t)(uintptr_t)h, .count_handles = 1, .timeout_nsec = (int64_t)(ns() + 2000000000ull)};
			if (xioctl(DRM_IOCTL_SYNCOBJ_WAIT, &w)) { printf("wait failed %d\n", errno); return 1; }
			if (tg[0] != seq) { printf("exec: store missing\n"); return 1; }
			if (i >= 5) lat[i - 5] = (t1 - t0) / 1e3;
		}
		printf("  exec    gap %5llu us\n", gaps[gi] / 1000);
		st("exec -> store visible", lat, n);
	}

	// 2. direct: one persistent batch, a slot per job
	int total = 0;
	for (int gi = 0; gi < 4; gi++) total += (gi == 3 ? N / 5 : N) + 5;
	for (int k = 0; k < total; k++) {
		volatile uint32_t *s = ring + (size_t)k * SLOT_DW;
		const uint64_t wa = WORK + (uint64_t)k * WORK_DW * 4;
		s[0] = MI_SEMA_GTE_POLL; s[1] = (uint32_t)(k + 1); s[2] = MBOX; s[3] = 0; s[4] = 0;
		s[5] = MI_BBS2; s[6] = (uint32_t)wa; s[7] = (uint32_t)(wa >> 32);
		// after the call returns: the job number to the second dword (0 jobs' worth of extra work without chain: a no-op
		// store to an unused dword keeps the slot the same size)
		s[8] = MI_SDI; s[9] = TARGET + (chain ? 4 : 64); s[10] = 0; s[11] = (uint32_t)(k + 1);
	}
	ring[(size_t)total * SLOT_DW] = MI_BBE; ring[(size_t)total * SLOT_DW + 1] = 0;
	mbox[0] = 0; tg[0] = 0;
	flush(ring, (size_t)(total + 1) * SLOT_DW * 4); flush(mbox, 64); flush(tg, 64);
	struct drm_xe_sync s = {.type = DRM_XE_SYNC_TYPE_SYNCOBJ, .flags = DRM_XE_SYNC_FLAG_SIGNAL, .handle = sc.handle};
	struct drm_xe_exec x = {.exec_queue_id = q.exec_queue_id, .num_syncs = 1, .syncs = (uint64_t)(uintptr_t)&s, .address = RING, .num_batch_buffer = 1};
	if (xioctl(DRM_IOCTL_XE_EXEC, &x)) { printf("persistent exec failed %d\n", errno); return 1; }
	int k = 0;
	for (int gi = 0; gi < 4; gi++) {
		int n = gi == 3 ? N / 5 : N;
		for (int i = 0; i < n + 5; i++, k++) {
			volatile uint32_t *b = work + (size_t)k * WORK_DW;
			const uint32_t v = 0x80000000u | (uint32_t)k;
			if (chain) {   // stub: chain to dword 8 of the same slot, which stores and ends
				const uint64_t to = WORK + ((uint64_t)k * WORK_DW + 8) * 4;
				b[0] = MI_BBSC; b[1] = (uint32_t)to; b[2] = (uint32_t)(to >> 32); b[3] = 0;
				b[8] = MI_SDI; b[9] = TARGET; b[10] = 0; b[11] = v; b[12] = MI_BBE; b[13] = 0;
				flush(b, 64);
			} else {
				b[0] = MI_SDI; b[1] = TARGET; b[2] = 0; b[3] = v; b[4] = MI_BBE; b[5] = 0;
				flush(b, 32);
			}
			spin_ns(gaps[gi]);
			const uint64_t t0 = ns();
			mbox[0] = (uint32_t)(k + 1);
			flush(mbox, 64);
			while (tg[0] != v && ns() - t0 < 1000000000ull) __asm__ volatile("pause");
			const uint64_t t1 = ns();
			if (chain) {   // back in the persistent batch?
				while (tg[1] != (uint32_t)(k + 1) && ns() - t0 < 1000000000ull) __asm__ volatile("pause");
				if (tg[1] != (uint32_t)(k + 1)) { printf("chain: job %d stored 0x%x but the persistent batch did not go on (0x%x)\n", k, tg[0], tg[1]);
					mbox[0] = 0xffffffffu; flush(mbox, 64); return 1; }
			}
			if (tg[0] != v) { printf("direct: store missing at job %d (mailbox %u, target 0x%x)\n", k, mbox[0], tg[0]); mbox[0] = 0xffffffffu; flush(mbox, 64); return 1; }
			if (i >= 5) lat[i - 5] = (t1 - t0) / 1e3;
		}
		printf("  direct  gap %5llu us\n", gaps[gi] / 1000);
		st("mailbox -> store visible", lat, n);
	}
	struct drm_syncobj_wait w = {.handles = (uint64_t)(uintptr_t)h, .count_handles = 1, .timeout_nsec = (int64_t)(ns() + 2000000000ull)};
	if (xioctl(DRM_IOCTL_SYNCOBJ_WAIT, &w)) printf("persistent batch did not end: %d\n", errno);
	struct drm_xe_exec_queue_destroy d = {.exec_queue_id = q.exec_queue_id};
	xioctl(DRM_IOCTL_XE_EXEC_QUEUE_DESTROY, &d);
	return 0;
}
