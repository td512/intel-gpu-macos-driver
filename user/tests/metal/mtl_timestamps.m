// SPDX-License-Identifier: MIT
// mtl_timestamps: Metal GPU timestamps (MTLCommonCounterSetTimestamp) as WebKit's WebGPU 'timestamp-query' uses them,
// and as profilers do.
//
// Two command buffers, each: a render pass, two compute passes (a spin kernel of N and 4N iterations) and a blit pass,
// each sampled at its stage boundaries through the pass descriptor's sampleBufferAttachments: the first into a sample
// buffer of shared storage resolved on the CPU (-resolveCounterRange:), the second into one of private storage resolved
// by a blit encoder (-resolveCounters:inRange:destinationBuffer:destinationOffset:). Where the device samples at
// dispatch / draw / blit boundaries, -sampleCountersInBuffer:atSampleIndex:withBarrier: brackets a dispatch, a draw and
// a copy too. Checks:
//   - every sampled index resolves (not MTLCounterErrorValue); the 4N pass measures alike (0.5..2x) through both resolves
//   - start <= end inside every pass; on the B580 the passes follow each other in the order encoded (within 50 us; Apple's
//     GPU overlaps independent passes)
//   - durations are nanoseconds: the 4N spin pass measures 2..8x the N one (B580), each > 0 and < 1 s, and the two spin
//     passes together are at most the command buffer's GPUEndTime - GPUStartTime (+ 1 ms) and at least a quarter of it
//   - -sampleTimestamps:gpuTimestamp: brackets the samples: every timestamp lies between the GPU timestamps sampled
//     before commit and after completion (+/- 2 ms), and the GPU clock advances at the CPU clock's rate (0.9..1.1)
//   - an index never sampled resolves to MTLCounterErrorValue (enforced on the B580, reported elsewhere)
//
//   NVMTL_ENABLE=1 ./mtl_timestamps          on the B580 (NVMTL_ENABLE passes the plugin's allow-list)
//   ./mtl_timestamps --any                   on the first Metal device when no B580 is present (reference run)
//
// Exit: 0 pass, 1 no device / no timestamp counters / no stage-boundary sampling, 2 compile/pipeline failure,
//       3 GPU error, 4 wrong values.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <IOKit/IOKitLib.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <string.h>

static NSString *const kSource =
    @"#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "kernel void spin(device uint *o [[buffer(0)]], constant uint &n [[buffer(1)]], uint g [[thread_position_in_grid]]) {\n"
     "    uint x = g;\n"
     "    for (uint i = 0; i < n; i++) x = x * 1664525u + 1013904223u;\n"
     "    o[g] = x;\n"
     "}\n"
     "struct V { float4 p [[position]]; };\n"
     "vertex V vs(uint i [[vertex_id]]) {\n"
     "    const float2 c[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };\n"
     "    V v; v.p = float4(c[i], 0, 1); return v;\n"
     "}\n"
     "fragment float4 fs(V v [[stage_in]]) { return float4(v.p.x / 512.0, v.p.y / 512.0, 0.5, 1); }\n";

enum {
    S_RV0, S_RV1, S_RF0, S_RF1,     // render pass: start/end of vertex, start/end of fragment
    S_C0, S_C1,                     // compute pass, N iterations
    S_D0, S_D1,                     // compute pass, 4N iterations
    S_B0, S_B1,                     // blit pass
    S_XD0, S_XD1,                   // sampleCountersInBuffer around a dispatch (dispatch boundary)
    S_XR0, S_XR1,                   // ... around a draw (draw boundary)
    S_XB0, S_XB1,                   // ... around a copy (blit boundary)
    S_NEVER,                        // never sampled
    S_COUNT = 24
};
static const char *const kName[S_COUNT] = { "render vertex start", "render vertex end", "render fragment start",
    "render fragment end", "compute N start", "compute N end", "compute 4N start", "compute 4N end", "blit start", "blit end",
    "dispatch sample before", "dispatch sample after", "draw sample before", "draw sample after", "copy sample before",
    "copy sample after", "never sampled" };

static uint64_t nmx_registry_id(void)
{
    io_service_t s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("NMXAccel"));
    if (!s) return 0;
    uint64_t id = 0;
    IORegistryEntryGetRegistryEntryID(s, &id);
    IOObjectRelease(s);
    return id;
}

static int g_bad;
#define CHECK(cond, ...) do { if (!(cond)) { g_bad++; printf("  FAIL: "); printf(__VA_ARGS__); printf("\n"); } } while (0)

static double cpu_ns(uint64_t mach)
{
    static mach_timebase_info_data_t tb;
    if (!tb.denom) mach_timebase_info(&tb);
    return (double)mach * tb.numer / tb.denom;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        const BOOL any = argc > 1 && !strcmp(argv[1], "--any");
        const uint64_t nmx = nmx_registry_id();
        id<MTLDevice> dev = nil;
        BOOL ours = NO;
        for (id<MTLDevice> d in MTLCopyAllDevices()) {
            ours = (nmx && d.registryID == nmx) || [NSStringFromClass([d class]) isEqualToString:@"NVMTLDevice"];
            if (ours || (any && !dev)) dev = d;
            if (ours) break;
        }
        if (!dev) { fprintf(stderr, "FAIL: no B580 Metal device (--any runs on the first device)\n"); return 1; }
        printf("device: %s (%s)\n", dev.name.UTF8String, NSStringFromClass([dev class]).UTF8String);

        const MTLCounterSamplingPoint points[4] = { MTLCounterSamplingPointAtStageBoundary, MTLCounterSamplingPointAtDrawBoundary,
                                                    MTLCounterSamplingPointAtDispatchBoundary, MTLCounterSamplingPointAtBlitBoundary };
        BOOL sp[4];
        for (int i = 0; i < 4; i++) sp[i] = [dev supportsCounterSampling:points[i]];
        printf("supportsCounterSampling: stage %d draw %d dispatch %d blit %d\n", sp[0], sp[1], sp[2], sp[3]);
        id<MTLCounterSet> set = nil;
        printf("counterSets:");
        for (id<MTLCounterSet> s in dev.counterSets) {
            printf(" %s{", s.name.UTF8String);
            for (id<MTLCounter> c in s.counters) printf(" %s", c.name.UTF8String);
            printf(" }");
            if ([s.name isEqualToString:MTLCommonCounterSetTimestamp]) set = s;
        }
        printf("\n");
        if (!set) { fprintf(stderr, "FAIL: no %s counter set\n", MTLCommonCounterSetTimestamp.UTF8String); return 1; }
        BOOL hasTs = NO;
        for (id<MTLCounter> c in set.counters) hasTs |= [c.name isEqualToString:MTLCommonCounterTimestamp];
        if (!hasTs) { fprintf(stderr, "FAIL: the timestamp set has no %s counter\n", MTLCommonCounterTimestamp.UTF8String); return 1; }
        if (!sp[0]) { fprintf(stderr, "FAIL: no sampling at stage boundaries (WebKit offers no 'timestamp-query' without it)\n"); return 1; }

        NSError *err = nil;
        MTLCounterSampleBufferDescriptor *sd = [MTLCounterSampleBufferDescriptor new];
        sd.counterSet = set; sd.sampleCount = S_COUNT; sd.storageMode = MTLStorageModeShared; sd.label = @"ts shared";
        id<MTLCounterSampleBuffer> shared = [dev newCounterSampleBufferWithDescriptor:sd error:&err];
        if (!shared) { fprintf(stderr, "FAIL: shared sample buffer: %s\n", err.localizedDescription.UTF8String); return 1; }
        sd.storageMode = MTLStorageModePrivate; sd.label = @"ts private";
        id<MTLCounterSampleBuffer> priv = [dev newCounterSampleBufferWithDescriptor:sd error:&err];
        if (!priv) { fprintf(stderr, "FAIL: private sample buffer: %s\n", err.localizedDescription.UTF8String); return 1; }
        sd.counterSet = nil;
        id<MTLCounterSampleBuffer> noset = [dev newCounterSampleBufferWithDescriptor:sd error:&err];
        printf("a descriptor without a counter set: %s (%s)\n", noset ? "accepted" : "refused", err ? err.localizedDescription.UTF8String : "no error");

        id<MTLLibrary> lib = [dev newLibraryWithSource:kSource options:[MTLCompileOptions new] error:&err];
        if (!lib) { fprintf(stderr, "FAIL: newLibraryWithSource: %s\n", err.localizedDescription.UTF8String); return 2; }
        id<MTLComputePipelineState> spin = [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"spin"] error:&err];
        MTLRenderPipelineDescriptor *rpd = [MTLRenderPipelineDescriptor new];
        rpd.vertexFunction = [lib newFunctionWithName:@"vs"]; rpd.fragmentFunction = [lib newFunctionWithName:@"fs"];
        rpd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        id<MTLRenderPipelineState> rps = spin ? [dev newRenderPipelineStateWithDescriptor:rpd error:&err] : nil;
        if (!spin || !rps) { fprintf(stderr, "FAIL: pipeline: %s\n", err.localizedDescription.UTF8String); return 2; }

        id<MTLCommandQueue> q = [dev newCommandQueue];
        const NSUInteger threads = 65536;
        id<MTLBuffer> out = [dev newBufferWithLength:threads * 4 options:MTLResourceStorageModePrivate];
        id<MTLBuffer> src = [dev newBufferWithLength:16 << 20 options:MTLResourceStorageModePrivate];
        id<MTLBuffer> dst = [dev newBufferWithLength:16 << 20 options:MTLResourceStorageModePrivate];
        id<MTLBuffer> resolved = [dev newBufferWithLength:S_COUNT * 8 + 64 options:MTLResourceStorageModeShared];
        memset(resolved.contents, 0x5a, resolved.length);
        MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:512 height:512 mipmapped:NO];
        td.usage = MTLTextureUsageRenderTarget; td.storageMode = MTLStorageModePrivate;
        id<MTLTexture> rt = [dev newTextureWithDescriptor:td];

        // the spin kernel sized to take about 10 ms here (two command buffers without counters)
        uint32_t n = 1024;
        for (int k = 0; k < 2; k++) {
            id<MTLCommandBuffer> cb = [q commandBuffer];
            id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
            [ce setComputePipelineState:spin]; [ce setBuffer:out offset:0 atIndex:0]; [ce setBytes:&n length:4 atIndex:1];
            [ce dispatchThreads:MTLSizeMake(threads, 1, 1) threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
            [ce endEncoding];
            const uint64_t c0 = mach_absolute_time();
            [cb commit]; [cb waitUntilCompleted];
            const double wall = cpu_ns(mach_absolute_time() - c0);
            double gpu = (cb.GPUEndTime - cb.GPUStartTime) * 1e9;
            if (!(gpu > 0) || gpu > wall * 2) gpu = wall;
            if (cb.status != MTLCommandBufferStatusCompleted) { fprintf(stderr, "FAIL: sizing command buffer: %s\n", cb.error.localizedDescription.UTF8String); return 3; }
            const double want = 10e6, scale = want / (gpu > 1e3 ? gpu : 1e3);
            const double nn = n * (scale > 64 ? 64 : scale < 1.0 / 64 ? 1.0 / 64 : scale);
            printf("sizing: %u iterations take %.3f ms (GPU) / %.3f ms (wall)\n", n, gpu / 1e6, wall / 1e6);
            n = nn < 64 ? 64 : nn > 1e8 ? 100000000u : (uint32_t)nn;
        }
        const uint32_t n4 = n * 4;
        printf("spin: N = %u iterations x %lu threads\n", n, (unsigned long)threads);

        // run 0: the shared buffer, resolved on the CPU; run 1: the private buffer, resolved by a blit encoder into a
        // shared MTLBuffer 8 bytes in (Apple's GPU samples only the first of several attachments, so one buffer per run)
        uint64_t ts[2][S_COUNT];
        double durN[2] = { 0, 0 }, dur4N[2] = { 0, 0 };
        for (int run = 0; run < 2; run++) {
            id<MTLCounterSampleBuffer> sb = run ? priv : shared;
            printf("-- run %d: %s sample buffer, %s\n", run, run ? "private" : "shared",
                   run ? "resolveCounters:inRange:destinationBuffer:destinationOffset:" : "resolveCounterRange:");
            id<MTLCommandBuffer> cb = [q commandBuffer];
            MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
            rp.colorAttachments[0].texture = rt; rp.colorAttachments[0].loadAction = MTLLoadActionClear;
            rp.colorAttachments[0].storeAction = MTLStoreActionStore; rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
            MTLRenderPassSampleBufferAttachmentDescriptor *at = rp.sampleBufferAttachments[0];
            at.sampleBuffer = sb;
            at.startOfVertexSampleIndex = S_RV0; at.endOfVertexSampleIndex = S_RV1;
            at.startOfFragmentSampleIndex = S_RF0; at.endOfFragmentSampleIndex = S_RF1;
            id<MTLRenderCommandEncoder> re = [cb renderCommandEncoderWithDescriptor:rp];
            [re setRenderPipelineState:rps];
            for (int k = 0; k < 64; k++) [re drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
            [re endEncoding];
            const uint32_t iters[2] = { n, n4 };
            const int idx[2][2] = { { S_C0, S_C1 }, { S_D0, S_D1 } };
            for (int p = 0; p < 2; p++) {
                MTLComputePassDescriptor *cp = [MTLComputePassDescriptor computePassDescriptor];
                cp.sampleBufferAttachments[0].sampleBuffer = sb;
                cp.sampleBufferAttachments[0].startOfEncoderSampleIndex = idx[p][0];
                cp.sampleBufferAttachments[0].endOfEncoderSampleIndex = idx[p][1];
                id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoderWithDescriptor:cp];
                [ce setComputePipelineState:spin]; [ce setBuffer:out offset:0 atIndex:0]; [ce setBytes:&iters[p] length:4 atIndex:1];
                [ce dispatchThreads:MTLSizeMake(threads, 1, 1) threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
                [ce endEncoding];
            }
            MTLBlitPassDescriptor *bp = [MTLBlitPassDescriptor blitPassDescriptor];
            bp.sampleBufferAttachments[0].sampleBuffer = sb;
            bp.sampleBufferAttachments[0].startOfEncoderSampleIndex = S_B0;
            bp.sampleBufferAttachments[0].endOfEncoderSampleIndex = S_B1;
            id<MTLBlitCommandEncoder> be = [cb blitCommandEncoderWithDescriptor:bp];
            [be copyFromBuffer:src sourceOffset:0 toBuffer:dst destinationOffset:0 size:src.length];
            [be endEncoding];
            if (sp[2]) {
                id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
                [ce setComputePipelineState:spin]; [ce setBuffer:out offset:0 atIndex:0]; [ce setBytes:&n length:4 atIndex:1];
                [ce sampleCountersInBuffer:sb atSampleIndex:S_XD0 withBarrier:YES];
                [ce dispatchThreads:MTLSizeMake(threads, 1, 1) threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
                [ce sampleCountersInBuffer:sb atSampleIndex:S_XD1 withBarrier:YES];
                [ce endEncoding];
            }
            if (sp[1]) {
                MTLRenderPassDescriptor *rp2 = [MTLRenderPassDescriptor renderPassDescriptor];
                rp2.colorAttachments[0].texture = rt; rp2.colorAttachments[0].loadAction = MTLLoadActionLoad;
                rp2.colorAttachments[0].storeAction = MTLStoreActionStore;
                id<MTLRenderCommandEncoder> r2 = [cb renderCommandEncoderWithDescriptor:rp2];
                [r2 setRenderPipelineState:rps];
                [r2 sampleCountersInBuffer:sb atSampleIndex:S_XR0 withBarrier:YES];
                for (int k = 0; k < 16; k++) [r2 drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
                [r2 sampleCountersInBuffer:sb atSampleIndex:S_XR1 withBarrier:YES];
                [r2 endEncoding];
            }
            if (sp[3]) {
                id<MTLBlitCommandEncoder> b2 = [cb blitCommandEncoder];
                [b2 sampleCountersInBuffer:sb atSampleIndex:S_XB0 withBarrier:YES];
                [b2 copyFromBuffer:dst sourceOffset:0 toBuffer:src destinationOffset:0 size:src.length];
                [b2 sampleCountersInBuffer:sb atSampleIndex:S_XB1 withBarrier:YES];
                [b2 endEncoding];
            }
            if (run) {
                id<MTLBlitCommandEncoder> rb = [cb blitCommandEncoder];
                [rb resolveCounters:sb inRange:NSMakeRange(0, S_COUNT) destinationBuffer:resolved destinationOffset:8];
                [rb endEncoding];
            }

            MTLTimestamp cpu0 = 0, gpu0 = 0, cpu1 = 0, gpu1 = 0;
            [dev sampleTimestamps:&cpu0 gpuTimestamp:&gpu0];
            [cb commit];
            [cb waitUntilCompleted];
            [dev sampleTimestamps:&cpu1 gpuTimestamp:&gpu1];
            if (cb.status != MTLCommandBufferStatusCompleted) { fprintf(stderr, "FAIL: command buffer: %s\n", cb.error.localizedDescription.UTF8String); return 3; }

            uint64_t *t = ts[run];
            if (!run) {
                NSData *cpuData = [sb resolveCounterRange:NSMakeRange(0, S_COUNT)];
                if (!cpuData || cpuData.length < S_COUNT * sizeof(MTLCounterResultTimestamp)) {
                    fprintf(stderr, "FAIL: resolveCounterRange returned %lu bytes\n", (unsigned long)cpuData.length); return 4; }
                memcpy(t, cpuData.bytes, S_COUNT * 8);
            } else {
                const uint64_t *r = (const uint64_t *)resolved.contents;
                CHECK(r[0] == 0x5a5a5a5a5a5a5a5aull, "resolveCounters wrote before its destination offset (%016llx)", r[0]);
                CHECK(r[1 + S_COUNT] == 0x5a5a5a5a5a5a5a5aull, "resolveCounters wrote past its range (%016llx)", r[1 + S_COUNT]);
                memcpy(t, r + 1, S_COUNT * 8);
            }

            const double cdt = cpu_ns(cpu1 - cpu0), gdt = (double)(gpu1 - gpu0);
            printf("sampleTimestamps: cpu %llu -> %llu, gpu %llu -> %llu; gpu/cpu rate %.4f over %.3f ms\n", cpu0, cpu1, gpu0, gpu1,
                   cdt > 0 ? gdt / cdt : 0.0, cdt / 1e6);
            const double cbgpu = (cb.GPUEndTime - cb.GPUStartTime) * 1e9;
            printf("command buffer GPU time %.3f ms\n", cbgpu / 1e6);
            if (cdt > 1e6) CHECK(gdt / cdt > 0.9 && gdt / cdt < 1.1, "the GPU clock advanced %.4f x the CPU clock", gdt / cdt);
            CHECK(gpu0 && gpu1 && gpu1 >= gpu0, "sampleTimestamps: gpu %llu then %llu", gpu0, gpu1);

            BOOL sampled[S_COUNT] = { 0 };
            for (int i = S_RV0; i <= S_B1; i++) sampled[i] = YES;
            if (sp[2]) sampled[S_XD0] = sampled[S_XD1] = YES;
            if (sp[1]) sampled[S_XR0] = sampled[S_XR1] = YES;
            if (sp[3]) sampled[S_XB0] = sampled[S_XB1] = YES;
            const uint64_t base = t[S_RV0];
            printf("  %-24s %20s %12s\n", "sample", "timestamp", "+us");
            for (int i = 0; i <= S_NEVER; i++) {
                printf("  %-24s %20llu", kName[i], t[i]);
                if (sampled[i] && t[i] != MTLCounterErrorValue && t[i] && base != MTLCounterErrorValue)
                    printf(" %12.3f", ((double)t[i] - (double)base) / 1e3);
                printf("%s\n", sampled[i] ? "" : "  (not sampled)");
                if (!sampled[i]) continue;
                CHECK(t[i] != MTLCounterErrorValue && t[i] != 0, "%s: no timestamp", kName[i]);
                const double lo = (double)gpu0 - 2e6, hi = (double)gpu1 + 2e6;
                CHECK((double)t[i] >= lo && (double)t[i] <= hi, "%s: %llu lies outside the sampleTimestamps bracket %llu..%llu", kName[i], t[i], gpu0, gpu1);
            }
            if (ours) CHECK(t[S_NEVER] == MTLCounterErrorValue, "never sampled: %llu, not MTLCounterErrorValue", t[S_NEVER]);
            else printf("never sampled: %s (reference only)\n", t[S_NEVER] == MTLCounterErrorValue ? "MTLCounterErrorValue" : "a value");

            #define OK2(i) (t[i] != MTLCounterErrorValue && t[i] != 0)
            int pairs[][2] = { { S_RV0, S_RV1 }, { S_RF0, S_RF1 }, { S_RV0, S_RF1 }, { S_C0, S_C1 }, { S_D0, S_D1 }, { S_B0, S_B1 },
                               { S_XD0, S_XD1 }, { S_XR0, S_XR1 }, { S_XB0, S_XB1 } };
            for (unsigned k = 0; k < sizeof pairs / sizeof pairs[0]; k++) {
                const int a = pairs[k][0], b = pairs[k][1];
                if (!sampled[a] || !OK2(a) || !OK2(b)) continue;
                const double d = (double)t[b] - (double)t[a];
                printf("  %-22s -> %-22s %10.3f us\n", kName[a], kName[b], d / 1e3);
                CHECK(d >= 0 && d < 1e9, "%s -> %s: %.0f ns", kName[a], kName[b], d);
            }
            // in the order encoded, within 50 us (Apple's GPU overlaps independent passes: reported there, not checked)
            int order[] = { S_RF1, S_C0, S_C1, S_D0, S_D1, S_B0, S_B1 };
            for (unsigned k = 1; k < sizeof order / sizeof order[0]; k++)
                if (OK2(order[k - 1]) && OK2(order[k]) && (double)t[order[k]] + 50e3 < (double)t[order[k - 1]]) {
                    if (ours) CHECK(0, "%s (%llu) is before %s (%llu)", kName[order[k]], t[order[k]], kName[order[k - 1]], t[order[k - 1]]);
                    else printf("  (reference) %s is before %s: passes overlap\n", kName[order[k]], kName[order[k - 1]]);
                }
            if (OK2(S_C0) && OK2(S_C1) && OK2(S_D0) && OK2(S_D1)) {
                const double d1 = (double)t[S_C1] - (double)t[S_C0], d4 = (double)t[S_D1] - (double)t[S_D0];
                durN[run] = d1; dur4N[run] = d4;
                printf("compute: N %.3f ms, 4N %.3f ms (x%.2f)\n", d1 / 1e6, d4 / 1e6, d1 > 0 ? d4 / d1 : 0.0);
                CHECK(d1 > 0 && d4 > 0, "a spin pass measured no time");
                // Apple's GPU runs the N pass alongside the render and blit passes: its ratio is reported there, not checked
                if (ours) CHECK(d1 > 0 && d4 / d1 >= 2.0 && d4 / d1 <= 8.0, "4N/N = %.2f, not 2..8", d1 > 0 ? d4 / d1 : 0.0);
                if (cbgpu > 0) {
                    CHECK(d1 + d4 <= cbgpu + 1e6, "the spin passes (%.3f ms) outlast the command buffer (%.3f ms): not nanoseconds?", (d1 + d4) / 1e6, cbgpu / 1e6);
                    CHECK(d1 + d4 >= cbgpu / 4, "the spin passes (%.3f ms) are under a quarter of the command buffer (%.3f ms): not nanoseconds?", (d1 + d4) / 1e6, cbgpu / 1e6);
                }
            }
            #undef OK2
        }
        if (dur4N[0] > 0 && dur4N[1] > 0)
            CHECK(dur4N[1] / dur4N[0] > 0.5 && dur4N[1] / dur4N[0] < 2.0, "the 4N pass measured %.3f ms (CPU resolve) and %.3f ms (GPU resolve)",
                  dur4N[0] / 1e6, dur4N[1] / 1e6);
        printf("%s (%d failed)\n", g_bad ? "FAIL" : "PASS", g_bad);
        return g_bad ? 4 : 0;
    }
}
