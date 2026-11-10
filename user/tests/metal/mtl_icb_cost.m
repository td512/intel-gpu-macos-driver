// SPDX-License-Identifier: MIT
// mtl_icb_cost: what a GPU-encodable indirect command buffer costs per slot on the Arc B580.
//
// An ICB whose gpuResourceID is taken (a shader may write it) is executed from its slot records: every slot issues
// vkCmdDrawIndirect, and an indexed slot issues vkCmdDrawIndexedIndirect before it (the form the record does not hold
// has zero counts), so an indexed slot is two indirect draws. An ICB nobody took the ID of replays its CPU-encoded
// draws as plain draws. This times the same N tiny draws (one 2x2-pixel quad each) four ways:
//   direct        drawIndexedPrimitives N times in the render encoder
//   icb-replay    an ICB of N CPU-encoded drawIndexed slots, ID not taken (CPU replay)
//   icb-records   the same with gpuResourceID taken first (records: 2 indirect draws per slot)
//   icb-rec-draw  N CPU-encoded drawPrimitives slots, ID taken (records: 1 indirect draw per slot)
// and reports the GPU time of each command buffer (GPUEndTime - GPUStartTime, median of the runs) and the CPU time of
// the encode, per slot. Every way draws the same pixels; the check compares the four images.
//
//   ./mtl_icb_cost [slots] [runs]          default 4096 slots, 15 runs
//   ./mtl_icb_cost --any [slots] [runs]    on the first Metal device when no B580 is present
//   MTL_ICB_COST_FLAT=1 ./mtl_icb_cost     a vertex shader without [[instance_id]] (one colour): on Xe2 ANV executes an
//                                          indirect draw with EXECUTE_INDIRECT_DRAW only when the shader reads no base
//                                          instance or vertex, which instance_id needs
//
// Exit: 0 done, 1 no device, 2 pipeline failure, 3 GPU error, 4 the images differ.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <IOKit/IOKitLib.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static NSString *const kSource =
    @"#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "struct VOut { float4 pos [[position]]; float4 col; };\n"
     "vertex VOut vmain(const device float2 *pos [[buffer(0)]], uint vid [[vertex_id]], uint iid [[instance_id]]) {\n"
     "    VOut o; o.pos = float4(pos[vid], 0.0, 1.0);\n"
     "    o.col = float4(float(iid & 255) / 255.0, float((iid >> 8) & 255) / 255.0, 0.5, 1.0); return o;\n"
     "}\n"
     "vertex VOut vflat(const device float2 *pos [[buffer(0)]], uint vid [[vertex_id]]) {\n"
     "    VOut o; o.pos = float4(pos[vid], 0.0, 1.0); o.col = float4(1.0, 0.5, 0.25, 1.0); return o;\n"
     "}\n"
     "fragment float4 fmain(VOut in [[stage_in]]) { return in.col; }\n";

static uint64_t nmx_registry_id(void)
{
    io_service_t s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("NMXAccel"));
    if (!s) return 0;
    uint64_t id = 0;
    IORegistryEntryGetRegistryEntryID(s, &id);
    IOObjectRelease(s);
    return id;
}

static int cmp_double(const void *a, const void *b)
{
    const double x = *(const double *)a, y = *(const double *)b;
    return x < y ? -1 : x > y;
}

static double median(double *v, int n)
{
    qsort(v, n, sizeof *v, cmp_double);
    return n & 1 ? v[n / 2] : (v[n / 2 - 1] + v[n / 2]) / 2;
}

enum { W = 256, H = 256, WAYS = 4 };
static const char *kWay[WAYS] = { "direct", "icb-replay", "icb-records", "icb-rec-draw" };

int main(int argc, char **argv)
{
    @autoreleasepool {
        int ai = 1;
        const BOOL any = argc > ai && !strcmp(argv[ai], "--any");
        if (any) ai++;
        const unsigned slots = argc > ai ? (unsigned)atoi(argv[ai]) : 4096;
        const int runs = argc > ai + 1 ? atoi(argv[ai + 1]) : 15;
        if (slots < 1 || slots > 65536 || runs < 1 || runs > 200) { fprintf(stderr, "usage: mtl_icb_cost [--any] [slots 1..65536] [runs 1..200]\n"); return 1; }

        const uint64_t nmx = nmx_registry_id();
        id<MTLDevice> dev = nil;
        for (id<MTLDevice> d in MTLCopyAllDevices()) {
            const BOOL ours = (nmx && d.registryID == nmx) || [NSStringFromClass([d class]) isEqualToString:@"NVMTLDevice"];
            if (ours || (any && !dev)) dev = d;
            if (ours) break;
        }
        if (!dev) { fprintf(stderr, "FAIL: no B580 Metal device (--any runs on the first device)\n"); return 1; }
        printf("device: %s (%s), %u slots, %d runs\n", dev.name.UTF8String, NSStringFromClass([dev class]).UTF8String, slots, runs);

        NSError *err = nil;
        id<MTLLibrary> lib = [dev newLibraryWithSource:kSource options:[MTLCompileOptions new] error:&err];
        if (!lib) { fprintf(stderr, "FAIL: newLibraryWithSource: %s\n", err.localizedDescription.UTF8String); return 2; }
        MTLRenderPipelineDescriptor *rd = [MTLRenderPipelineDescriptor new];
        const char *flat = getenv("MTL_ICB_COST_FLAT");
        rd.vertexFunction = [lib newFunctionWithName:flat && flat[0] == '1' ? @"vflat" : @"vmain"];
        rd.fragmentFunction = [lib newFunctionWithName:@"fmain"];
        rd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        rd.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
        rd.supportIndirectCommandBuffers = YES;
        id<MTLRenderPipelineState> ps = [dev newRenderPipelineStateWithDescriptor:rd error:&err];
        if (!ps) { fprintf(stderr, "FAIL: pipeline: %s\n", err.localizedDescription.UTF8String); return 2; }

        // slot k draws a 2x2-pixel quad at a cell of a 128x128 grid (4 vertices per slot; triangle list of 6 for the
        // non-indexed way), colour from its base instance; slots past 16384 wrap and overdraw
        const unsigned cells = 128 * 128, quads = slots < cells ? slots : cells;
        float (*v4)[2] = calloc(quads * 4, sizeof *v4), (*v6)[2] = calloc(quads * 6, sizeof *v6);
        for (unsigned k = 0; k < quads; k++) {
            const float px0 = (float)(k % 128) * 2, py0 = (float)(k / 128) * 2;
            const float x0 = px0 / W * 2 - 1, x1 = (px0 + 2) / W * 2 - 1, y0 = 1 - py0 / H * 2, y1 = 1 - (py0 + 2) / H * 2;
            const float c[4][2] = { { x0, y0 }, { x1, y0 }, { x0, y1 }, { x1, y1 } };
            memcpy(v4[4 * k], c, sizeof c);
            const float l[6][2] = { { x0, y0 }, { x1, y0 }, { x0, y1 }, { x0, y1 }, { x1, y0 }, { x1, y1 } };
            memcpy(v6[6 * k], l, sizeof l);
        }
        const uint16_t idx[6] = { 0, 1, 2, 2, 1, 3 };
        id<MTLBuffer> vb4 = [dev newBufferWithBytes:v4 length:quads * 4 * sizeof *v4 options:MTLResourceStorageModeShared];
        id<MTLBuffer> vb6 = [dev newBufferWithBytes:v6 length:quads * 6 * sizeof *v6 options:MTLResourceStorageModeShared];
        id<MTLBuffer> ib = [dev newBufferWithBytes:idx length:sizeof idx options:MTLResourceStorageModeShared];
        free(v4); free(v6);

        MTLIndirectCommandBufferDescriptor *idesc = [MTLIndirectCommandBufferDescriptor new];
        idesc.commandTypes = MTLIndirectCommandTypeDraw | MTLIndirectCommandTypeDrawIndexed;
        idesc.inheritPipelineState = YES;
        idesc.inheritBuffers = YES;
        id<MTLIndirectCommandBuffer> icbReplay = [dev newIndirectCommandBufferWithDescriptor:idesc maxCommandCount:slots options:0];
        id<MTLIndirectCommandBuffer> icbRec = [dev newIndirectCommandBufferWithDescriptor:idesc maxCommandCount:slots options:0];
        id<MTLIndirectCommandBuffer> icbRecDraw = [dev newIndirectCommandBufferWithDescriptor:idesc maxCommandCount:slots options:0];
        if (!icbReplay || !icbRec || !icbRecDraw) { fprintf(stderr, "FAIL: newIndirectCommandBufferWithDescriptor\n"); return 2; }
        // taking the ID makes the ICB GPU-encodable (records); taken before the slots are encoded, as WebKit orders it
        MTLResourceID id1 = icbRec.gpuResourceID, id2 = icbRecDraw.gpuResourceID;
        (void)id1; (void)id2;
        for (unsigned k = 0; k < slots; k++) {
            const unsigned q = k % quads;
            [[icbReplay indirectRenderCommandAtIndex:k] drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6
                indexType:MTLIndexTypeUInt16 indexBuffer:ib indexBufferOffset:0 instanceCount:1 baseVertex:4 * q baseInstance:q];
            [[icbRec indirectRenderCommandAtIndex:k] drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6
                indexType:MTLIndexTypeUInt16 indexBuffer:ib indexBufferOffset:0 instanceCount:1 baseVertex:4 * q baseInstance:q];
            [[icbRecDraw indirectRenderCommandAtIndex:k] drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:6 * q
                vertexCount:6 instanceCount:1 baseInstance:q];
        }

        MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:W height:H mipmapped:NO];
        td.usage = MTLTextureUsageRenderTarget; td.storageMode = MTLStorageModePrivate;
        id<MTLTexture> rt = [dev newTextureWithDescriptor:td];
        id<MTLBuffer> out[WAYS];
        for (int w = 0; w < WAYS; w++) out[w] = [dev newBufferWithLength:W * H * 4 options:MTLResourceStorageModeShared];
        id<MTLCommandQueue> q = [dev newCommandQueue];

        mach_timebase_info_data_t tb; mach_timebase_info(&tb);
        double *gpu = calloc((size_t)WAYS * runs, sizeof *gpu), *cpu = calloc((size_t)WAYS * runs, sizeof *cpu);
        // run 0 of each way warms up (pipeline variants, records) and is not counted; ways interleave per run
        for (int r = 0; r <= runs; r++) for (int w = 0; w < WAYS; w++) {
            id<MTLCommandBuffer> cmd = [q commandBuffer];
            MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
            rp.colorAttachments[0].texture = rt; rp.colorAttachments[0].loadAction = MTLLoadActionClear;
            rp.colorAttachments[0].storeAction = MTLStoreActionStore; rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
            id<MTLRenderCommandEncoder> re = [cmd renderCommandEncoderWithDescriptor:rp];
            [re setRenderPipelineState:ps];
            [re setVertexBuffer:(w == 3 ? vb6 : vb4) offset:0 atIndex:0];
            [re useResource:ib usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
            const uint64_t t0 = mach_absolute_time();
            if (w == 0) {
                for (unsigned k = 0; k < slots; k++) {
                    const unsigned qd = k % quads;
                    [re drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:ib
                            indexBufferOffset:0 instanceCount:1 baseVertex:4 * qd baseInstance:qd];
                }
            } else {
                id<MTLIndirectCommandBuffer> icb = w == 1 ? icbReplay : w == 2 ? icbRec : icbRecDraw;
                [re useResource:icb usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
                [re executeCommandsInBuffer:icb withRange:NSMakeRange(0, slots)];
            }
            const uint64_t t1 = mach_absolute_time();
            [re endEncoding];
            if (r == runs) {
                id<MTLBlitCommandEncoder> be = [cmd blitCommandEncoder];
                [be copyFromTexture:rt sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(W, H, 1)
                           toBuffer:out[w] destinationOffset:0 destinationBytesPerRow:W * 4 destinationBytesPerImage:W * H * 4];
                [be endEncoding];
            }
            [cmd commit];
            [cmd waitUntilCompleted];
            if (cmd.status != MTLCommandBufferStatusCompleted) {
                fprintf(stderr, "FAIL: %s run %d: command buffer status %ld: %s\n", kWay[w], r, (long)cmd.status,
                        cmd.error.localizedDescription.UTF8String ?: "");
                return 3;
            }
            if (r > 0) {
                gpu[w * runs + r - 1] = (cmd.GPUEndTime - cmd.GPUStartTime) * 1e6;           // us
                cpu[w * runs + r - 1] = (double)(t1 - t0) * tb.numer / tb.denom / 1e3;      // us
            }
        }

        double g[WAYS], c[WAYS];
        for (int w = 0; w < WAYS; w++) { g[w] = median(gpu + w * runs, runs); c[w] = median(cpu + w * runs, runs); }
        printf("%-13s %12s %12s %12s %12s\n", "way", "GPU us", "GPU ns/slot", "encode us", "enc ns/slot");
        for (int w = 0; w < WAYS; w++)
            printf("%-13s %12.1f %12.1f %12.1f %12.1f\n", kWay[w], g[w], g[w] * 1e3 / slots, c[w], c[w] * 1e3 / slots);
        printf("records vs replay: GPU x%.2f (%+.1f ns/slot); one indirect draw per slot (icb-rec-draw) vs replay: GPU x%.2f\n",
               g[2] / g[1], (g[2] - g[1]) * 1e3 / slots, g[3] / g[1]);
        printf("the second (zero-count) indirect draw of an indexed slot: %+.1f ns/slot (icb-records - icb-rec-draw)\n",
               (g[2] - g[3]) * 1e3 / slots);

        int bad = 0;
        for (int w = 1; w < WAYS; w++) if (memcmp(out[0].contents, out[w].contents, W * H * 4)) {
            fprintf(stderr, "FAIL: %s drew a different image from direct\n", kWay[w]);
            bad++;
        }
        if (!bad) printf("PASS: the four ways drew the same image\n");
        free(gpu); free(cpu);
        return bad ? 4 : 0;
    }
}
