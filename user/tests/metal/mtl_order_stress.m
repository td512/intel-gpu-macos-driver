// SPDX-License-Identifier: MIT
// mtl_order_stress: many threads and queues committing small command buffers at once; checks what the Metal plugin's
// commit / execution-worker locking (NVMTL_LOCK_V2 against the class lock) must keep. Runs on any Metal device (an Apple
// GPU gives the reference behaviour), and on the B580 through the plugin.
//
//   order   per queue, GPU execution order = queue order (the order of -enqueue, commits come later and out of order
//           from several threads), two parts per command buffer (an event signal splits it) in order; completed
//           handlers per queue in queue order; each scheduled handler before its completed handler
//   events  producer/consumer queue pairs: the consumer waits for the producer's MTLSharedEvent / MTLEvent value k and
//           must read what the producer wrote for k; consumers are often committed before their producer
//   cpu     a command buffer waiting for a shared event the CPU signals later must not complete before the signal
//   waits   other threads wait (waitUntilScheduled / waitUntilCompleted) on command buffers they did not commit
//   a watchdog fails the run if no command buffer completes for 10 s (a deadlock: on WindowServer, a black screen)
//
// Build (here: arm64 for an Apple GPU; for the B580 add -arch x86_64):
//   clang -fobjc-arc -O2 -o mtl_order_stress mtl_order_stress.m -framework Foundation -framework Metal -framework IOKit
// Run: ./mtl_order_stress [seconds=20] [threads=8] [queues=4]
//   on the B580 a plugin build that is not installed: NVMTL_ENABLE=1 NVMTL_BUNDLE=<dir>/NVMTLDriver.bundle ./mtl_order_stress
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <Metal/Metal.h>
#import <objc/message.h>
#include <stdatomic.h>
#include <unistd.h>

static NSString *const kSource = @R"(
#include <metal_stdlib>
using namespace metal;
kernel void stamp(device atomic_uint *ctr [[buffer(0)]], device uint *log [[buffer(1)]], constant uint2 &a [[buffer(2)]],
                  uint t [[thread_position_in_grid]]) {
    if (t == 0) { uint s = atomic_fetch_add_explicit(ctr, 1u, memory_order_relaxed); if (s < a.y) log[s] = a.x; }
}
kernel void produce(device uint *slot [[buffer(0)]], constant uint2 &a [[buffer(1)]], uint t [[thread_position_in_grid]]) {
    if (t == 0) slot[a.x % a.y] = a.x;
}
kernel void consume(device const uint *slot [[buffer(0)]], device uint *res [[buffer(1)]], constant uint2 &a [[buffer(2)]],
                    uint t [[thread_position_in_grid]]) {
    if (t == 0) res[a.x % a.y] = slot[a.x % a.y] == a.x ? a.x : 0xffffffffu;
}
)";

static _Atomic long gFail, gDone, gCbs;
static _Atomic int gStop;
#define FAILF(...) do { if (atomic_fetch_add(&gFail, 1) < 20) { printf("FAIL: " __VA_ARGS__); printf("\n"); fflush(stdout); } } while (0)

static id<MTLDevice> bundleDevice(const char *path) {   // as mtl_tests.m: that plugin build in this process only
    NSBundle *b = [NSBundle bundleWithPath:@(path)];
    NSError *e = nil;
    if (![b loadAndReturnError:&e]) { printf("bundle %s: %s\n", path, e.localizedDescription.UTF8String); return nil; }
    Class cls = [b classNamed:@"NVMTLDevice"];
    if (!cls) return nil;
    io_iterator_t it = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &it) != KERN_SUCCESS) return nil;
    id<MTLDevice> dev = nil;
    for (io_service_t svc; !dev && (svc = IOIteratorNext(it)); IOObjectRelease(svc)) {
        CFTypeRef name = IORegistryEntryCreateCFProperty(svc, CFSTR("MetalPluginClassName"), kCFAllocatorDefault, 0);
        if (name && CFEqual(name, CFSTR("NVMTLDevice")))
            dev = ((id (*)(id, SEL, mach_port_t))objc_msgSend)([cls alloc], sel_registerName("initWithAcceleratorPort:"), svc);
        if (name) CFRelease(name);
    }
    IOObjectRelease(it);
    return dev;
}

enum { LOGCAP = 1 << 20, SLOTS = 4096 };
typedef struct {
    id<MTLCommandQueue> q;
    NSLock *enqueueLock;
    uint32_t seq;               // ids handed out (enqueue order), under enqueueLock
    id<MTLBuffer> ctr, log;
    id<MTLSharedEvent> split;   // signalled with seq: values rise in queue order
    NSLock *handlerLock; uint32_t lastCompleted;
} OrderQueue;

static id<MTLComputePipelineState> gStamp, gProduce, gConsume;
static void encodeStamp(id<MTLCommandBuffer> cb, OrderQueue *oq, uint32_t tag) {
    id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
    [e setComputePipelineState:gStamp];
    [e setBuffer:oq->ctr offset:0 atIndex:0]; [e setBuffer:oq->log offset:0 atIndex:1];
    uint32_t a[2] = { tag, LOGCAP }; [e setBytes:a length:sizeof a atIndex:2];
    [e dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(32, 1, 1)];
    [e endEncoding];
}

// order: a command buffer takes its place with -enqueue under the queue's lock, is encoded and committed outside it
static void orderOne(OrderQueue *oq, unsigned *seed) {
    id<MTLCommandBuffer> cb;
    uint32_t seq;
    [oq->enqueueLock lock];
    cb = [oq->q commandBuffer];
    seq = ++oq->seq;
    [cb enqueue];
    [oq->enqueueLock unlock];
    encodeStamp(cb, oq, seq * 2);
    [cb encodeSignalEvent:oq->split value:seq];   // a second part
    if (rand_r(seed) % 4 == 0) [cb encodeWaitForEvent:oq->split value:seq];   // satisfied by its own signal
    encodeStamp(cb, oq, seq * 2 + 1);
    __block _Atomic int scheduled = 0;
    [cb addScheduledHandler:^(id<MTLCommandBuffer> b) { atomic_store(&scheduled, 1); }];
    [cb addCompletedHandler:^(id<MTLCommandBuffer> b) {
        if (!atomic_load(&scheduled)) FAILF("cb %u: completed handler before its scheduled handler", seq);
        if (b.status != MTLCommandBufferStatusCompleted) FAILF("cb %u: status %ld, error %s", seq, (long)b.status, b.error.description.UTF8String);
        [oq->handlerLock lock];
        if (seq != oq->lastCompleted + 1) FAILF("queue %p: completed handler of %u after %u", (__bridge void *)oq->q, seq, oq->lastCompleted);
        oq->lastCompleted = seq;
        [oq->handlerLock unlock];
        atomic_fetch_add(&gDone, 1);
    }];
    if (rand_r(seed) % 8 == 0) usleep(rand_r(seed) % 200);   // commits out of enqueue order
    [cb commit];
    atomic_fetch_add(&gCbs, 1);
    if (rand_r(seed) % 64 == 0) {   // waited for by other threads too
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
            [cb waitUntilScheduled];
            if (cb.status < MTLCommandBufferStatusScheduled) FAILF("waitUntilScheduled returned at status %ld", (long)cb.status);
            [cb waitUntilCompleted];
            if (cb.status != MTLCommandBufferStatusCompleted) FAILF("waitUntilCompleted returned at status %ld", (long)cb.status);
        });
    }
}

static void checkOrderLogs(OrderQueue *oqs, int nq) {
    for (int i = 0; i < nq; i++) {
        const uint32_t n = *(uint32_t *)oqs[i].ctr.contents, m = n < LOGCAP ? n : LOGCAP;
        const uint32_t *log = oqs[i].log.contents;
        if (n != oqs[i].seq * 2) FAILF("queue %d: %u stamps for %u command buffers", i, n, oqs[i].seq);
        for (uint32_t k = 0; k < m; k++)
            if (log[k] != k + 2) { FAILF("queue %d: GPU order: stamp %u is %u (expected %u)", i, k, log[k], k + 2); break; }
        if (oqs[i].lastCompleted != oqs[i].seq) FAILF("queue %d: %u completed handlers of %u", i, oqs[i].lastCompleted, oqs[i].seq);
    }
}

// events: the consumer waits for value k of the producer's event and reads the producer's slot k. The consumer runs
// ahead (its waits are committed before the signals); at the end the producer produces up to what the consumer committed.
static void eventPair(id<MTLDevice> dev, int pair, double seconds) {
    id<MTLCommandQueue> pq = [dev newCommandQueue], cq = [dev newCommandQueue];
    id<MTLEvent> ev = (pair & 1) ? [dev newEvent] : [dev newSharedEvent];
    id<MTLBuffer> slot = [dev newBufferWithLength:SLOTS * 4 options:MTLResourceStorageModeShared];
    id<MTLBuffer> res = [dev newBufferWithLength:SLOTS * 4 options:MTLResourceStorageModeShared];
    dispatch_semaphore_t window = dispatch_semaphore_create(SLOTS / 4);   // the producer stays less than SLOTS ahead
    NSLock *endLock = [NSLock new];
    __block BOOL producerDone = NO; __block uint32_t consumerCommitted = 0, final = 0;
    __block _Atomic uint32_t consumed = 0;
    const NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate] + seconds;
    dispatch_group_t g = dispatch_group_create();
    dispatch_group_async(g, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{   // producer
        uint32_t target = UINT32_MAX;
        for (uint32_t k = 1; k <= target; k++) { @autoreleasepool {
            if (target == UINT32_MAX && (atomic_load(&gStop) || [NSDate timeIntervalSinceReferenceDate] >= end)) {
                // both sides end at the larger of what was produced and what the consumer committed
                [endLock lock]; producerDone = YES; final = MAX(consumerCommitted, k - 1); target = final; [endLock unlock];
                if (k > target) break;
            }
            dispatch_semaphore_wait(window, DISPATCH_TIME_FOREVER);
            id<MTLCommandBuffer> cb = [pq commandBuffer];
            id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
            [e setComputePipelineState:gProduce]; [e setBuffer:slot offset:0 atIndex:0];
            uint32_t a[2] = { k, SLOTS }; [e setBytes:a length:sizeof a atIndex:1];
            [e dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(32, 1, 1)]; [e endEncoding];
            [cb encodeSignalEvent:ev value:k];
            [cb commit]; atomic_fetch_add(&gCbs, 1);
            if (k % 97 == 0) usleep(300);   // let the consumer get ahead: its waits are committed before the signal
        } }
    });
    dispatch_group_async(g, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{   // consumer
        id<MTLCommandBuffer> last = nil;
        for (uint32_t k = 1;; k++) { @autoreleasepool {
            id<MTLCommandBuffer> cb = [cq commandBuffer];
            [cb encodeWaitForEvent:ev value:k];
            id<MTLComputeCommandEncoder> e = [cb computeCommandEncoder];
            [e setComputePipelineState:gConsume]; [e setBuffer:slot offset:0 atIndex:0]; [e setBuffer:res offset:0 atIndex:1];
            uint32_t a[2] = { k, SLOTS }; [e setBytes:a length:sizeof a atIndex:2];
            [e dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(32, 1, 1)]; [e endEncoding];
            [endLock lock];
            const BOOL stop = producerDone && k > final;
            if (!producerDone) consumerCommitted = k;
            [endLock unlock];
            if (stop) break;   // never produced: dropped uncommitted (no handler: Apple runs those of a released one)
            [cb addCompletedHandler:^(id<MTLCommandBuffer> b) {
                const uint32_t got = ((uint32_t *)res.contents)[k % SLOTS];
                if (got != k) FAILF("events pair %d (%s): consumer %u read %u", pair, (pair & 1) ? "MTLEvent" : "MTLSharedEvent", k, got);
                if (atomic_fetch_add(&consumed, 1) + 1 != k) FAILF("events pair %d: consumer handler %u out of order", pair, k);
                dispatch_semaphore_signal(window); atomic_fetch_add(&gDone, 1);
            }];
            [cb commit]; atomic_fetch_add(&gCbs, 1); last = cb;
        } }
        [last waitUntilCompleted];
    });
    dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
}

// cpu: a command buffer waiting for a shared event must not complete before the CPU signals it
static void cpuSignals(id<MTLDevice> dev, double seconds) {
    id<MTLCommandQueue> q = [dev newCommandQueue];
    id<MTLSharedEvent> ev = [dev newSharedEvent];
    const NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate] + seconds;
    for (uint64_t k = 1; !atomic_load(&gStop) && [NSDate timeIntervalSinceReferenceDate] < end; k++) { @autoreleasepool {
        id<MTLCommandBuffer> cb = [q commandBuffer];
        [cb encodeWaitForEvent:ev value:k];
        id<MTLBlitCommandEncoder> b = [cb blitCommandEncoder]; [b endEncoding];
        __block _Atomic int signalled = 0;
        [cb addCompletedHandler:^(id<MTLCommandBuffer> c) {
            if (!atomic_load(&signalled)) FAILF("cpu: command buffer waiting for %llu completed before the CPU signal", k);
            atomic_fetch_add(&gDone, 1);
        }];
        [cb commit]; atomic_fetch_add(&gCbs, 1);
        usleep(100 + (unsigned)(k % 5) * 100);
        if (cb.status >= MTLCommandBufferStatusCompleted) FAILF("cpu: status %ld before the signal", (long)cb.status);
        atomic_store(&signalled, 1);
        ev.signaledValue = k;
        [cb waitUntilCompleted];
    } }
}

int main(int argc, char **argv) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        const double seconds = argc > 1 ? atof(argv[1]) : 20;
        const int threads = argc > 2 ? atoi(argv[2]) : 8, nq = argc > 3 ? atoi(argv[3]) : 4;
        id<MTLDevice> dev = nil;
        const char *bundle = getenv("NVMTL_BUNDLE");
        if (bundle) dev = bundleDevice(bundle);
        if (!dev) for (id<MTLDevice> d in MTLCopyAllDevices()) if ([NSStringFromClass([d class]) isEqualToString:@"NVMTLDevice"]) dev = d;
        if (!dev) dev = MTLCreateSystemDefaultDevice();
        if (!dev) { printf("no Metal device\n"); return 2; }
        printf("device %s (%s), %.0f s, %d threads, %d queues, NVMTL_LOCK_V2=%s\n", dev.name.UTF8String, NSStringFromClass([dev class]).UTF8String,
               seconds, threads, nq, getenv("NVMTL_LOCK_V2") ?: "unset");
        NSError *e = nil;
        id<MTLLibrary> lib = [dev newLibraryWithSource:kSource options:nil error:&e];
        if (!lib) { printf("library: %s\n", e.description.UTF8String); return 2; }
        gStamp = [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"stamp"] error:&e];
        gProduce = [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"produce"] error:&e];
        gConsume = [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"consume"] error:&e];
        if (!gStamp || !gProduce || !gConsume) { printf("pipelines: %s\n", e.description.UTF8String); return 2; }

        OrderQueue *oqs = calloc((size_t)nq, sizeof *oqs);
        for (int i = 0; i < nq; i++) {
            oqs[i].q = [dev newCommandQueue]; oqs[i].enqueueLock = [NSLock new]; oqs[i].handlerLock = [NSLock new];
            oqs[i].ctr = [dev newBufferWithLength:4 options:MTLResourceStorageModeShared];
            oqs[i].log = [dev newBufferWithLength:LOGCAP * 4 options:MTLResourceStorageModeShared];
            *(uint32_t *)oqs[i].ctr.contents = 0;
            oqs[i].split = [dev newSharedEvent];
        }
        const double t0 = [NSDate timeIntervalSinceReferenceDate];
        // watchdog
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            long last = -1; int still = 0;
            while (!atomic_load(&gStop)) {
                sleep(1);
                const long now = atomic_load(&gDone);
                if (now == last) { if (++still >= 10) { printf("FAIL: HANG - no command buffer completed for 10 s (%ld committed, %ld completed)\n", atomic_load(&gCbs), now); fflush(stdout); _exit(3); } }
                else still = 0;
                last = now;
            }
        });
        dispatch_group_t g = dispatch_group_create();
        for (int t = 0; t < threads; t++)
            dispatch_group_async(g, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                unsigned seed = 77u + (unsigned)t;
                const NSTimeInterval end = t0 + seconds;
                while ([NSDate timeIntervalSinceReferenceDate] < end && !atomic_load(&gStop)) { @autoreleasepool {
                    orderOne(&oqs[(t + (int)(rand_r(&seed) % 3 == 0 ? rand_r(&seed) : 0)) % nq], &seed);
                } }
            });
        for (int p = 0; p < 2; p++) dispatch_group_async(g, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ eventPair(dev, p, seconds); });
        dispatch_group_async(g, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ cpuSignals(dev, seconds); });
        dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
        for (int i = 0; i < nq; i++) {   // the last of each queue, and so all of it
            id<MTLCommandBuffer> cb = [oqs[i].q commandBuffer]; [cb commit]; [cb waitUntilCompleted];
        }
        for (int w = 0; w < 100; w++) {   // handlers run after completion, on their own queues
            BOOL all = YES; for (int i = 0; i < nq; i++) { [oqs[i].handlerLock lock]; all &= oqs[i].lastCompleted == oqs[i].seq; [oqs[i].handlerLock unlock]; }
            if (all) break;
            usleep(20000);
        }
        checkOrderLogs(oqs, nq);
        atomic_store(&gStop, 1);
        const double dt = [NSDate timeIntervalSinceReferenceDate] - t0;
        printf("%ld command buffers committed, %ld handlers checked, %.1f k cb/s: %s (%ld failures)\n", atomic_load(&gCbs), atomic_load(&gDone),
               atomic_load(&gCbs) / dt / 1000.0, atomic_load(&gFail) ? "FAILED" : "PASS", atomic_load(&gFail));
        return atomic_load(&gFail) ? 1 : 0;
    }
}
