// SPDX-License-Identifier: MIT
// mtl_gpu_icb: draws a shader encodes into an MTLIndirectCommandBuffer (render_command), then executed, on the Arc B580.
//
// One ICB of six slots (inheritPipelineState and inheritBuffers: the encoder's pipeline and buffers draw every slot), a
// 96x64 target cut into six 32x32 cells, cell k drawn by slot k with colour k (the vertex shader takes it from
// [[instance_id]], i.e. the slot's base instance):
//   0  a compute kernel encodes draw_primitives (6 vertices, triangle list)                        -> red
//   1  the CPU encodes drawIndexed (uint32, count 0); the kernel rewrites it with an index pointer six
//      indices into that buffer (first index 6) and base vertex 4                                 -> green
//   2  the same with uint16 indices and base vertex 8                                             -> blue
//   3  the CPU encodes a drawIndexed nothing touches                                              -> yellow
//   4  the CPU encodes a drawIndexed; a vertex shader with rasterization off (WebKit's vsICB
//      index-validation pattern) rewrites it with index count 0 in the same render pass, before
//      a memory barrier and the execute                                                           -> black
//   5  the CPU encodes a draw; the kernel resets the slot (render_command::reset)                  -> black
// The plugin translates the render_command calls to stores into the ICB's slot records (render_command.rs) and executes
// each slot with vkCmdDrawIndexedIndirect / vkCmdDrawIndirect from them (nvmtl_icb_layout.h).
//
//   NVMTL_ENABLE=1 ./mtl_gpu_icb          (NVMTL_ENABLE passes the plugin's allow-list)
//   ./mtl_gpu_icb --any                   run on the first Metal device when no B580 is present (reference run)
//
// Exit: 0 pass, 1 no B580 device, 2 compile/pipeline failure, 3 GPU error, 4 wrong pixels.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <IOKit/IOKitLib.h>
#include <stdio.h>
#include <string.h>

static NSString *const kSource =
    @"#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "struct Container { command_buffer cb [[id(0)]]; };\n"
     // the index pointers come from memory (gpuAddress), as in WebKit's vsICB: a pointer loaded from a buffer
     // carries its device address, a bound buffer parameter has none in the B580 translation
     "struct Ptrs { device uint *ib32; device ushort *ib16; };\n"
     "struct VOut { float4 pos [[position]]; float4 col; };\n"
     "vertex VOut vmain(const device float2 *pos [[buffer(0)]], const device float4 *cols [[buffer(1)]],\n"
     "                  uint vid [[vertex_id]], uint iid [[instance_id]]) {\n"
     "    VOut o; o.pos = float4(pos[vid], 0.0, 1.0); o.col = cols[iid]; return o;\n"
     "}\n"
     "fragment float4 fmain(VOut in [[stage_in]]) { return in.col; }\n"
     // the encoding kernel: one thread writes every slot it owns
     "kernel void encode(device Container *c [[buffer(0)]], const device Ptrs *p [[buffer(1)]],\n"
     "                   uint t [[thread_position_in_grid]]) {\n"
     "    if (t != 0) return;\n"
     "    render_command c0(c->cb, 0);\n"
     "    c0.draw_primitives(primitive_type::triangle, 16, 6, 1, 0);\n"
     "    render_command c1(c->cb, 1);\n"
     "    c1.draw_indexed_primitives(primitive_type::triangle, 6, p->ib32 + 6, 1, 4, 1);\n"
     "    render_command c2(c->cb, 2);\n"
     "    c2.draw_indexed_primitives(primitive_type::triangle, 6, p->ib16 + 6, 1, 8, 2);\n"
     "    render_command c5(c->cb, 5);\n"
     "    c5.reset();\n"
     "}\n"
     // WebKit's vsICB shape: a vertex shader, rasterization off, replaces a draw by an empty one
     "vertex void vclamp(device Container *c [[buffer(0)]], const device Ptrs *p [[buffer(1)]], uint vid [[vertex_id]]) {\n"
     "    render_command cmd(c->cb, 4);\n"
     "    cmd.draw_indexed_primitives(primitive_type::triangle, 0u, p->ib32, 1, 16, 4);\n"
     "}\n";

static uint64_t nmx_registry_id(void)
{
    io_service_t s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("NMXAccel"));
    if (!s) return 0;
    uint64_t id = 0;
    IORegistryEntryGetRegistryEntryID(s, &id);
    IOObjectRelease(s);
    return id;
}

enum { W = 96, H = 64, CELL = 32, SLOTS = 6 };

// cell k: column k % 3, row k / 3 (row 0 at the top), inset by 4 pixels, in clip space
static void cell_rect(unsigned k, float *x0, float *y0, float *x1, float *y1)
{
    const float px0 = (float)(k % 3) * CELL + 4, py0 = (float)(k / 3) * CELL + 4, px1 = px0 + CELL - 8, py1 = py0 + CELL - 8;
    *x0 = px0 / W * 2 - 1; *x1 = px1 / W * 2 - 1;
    *y0 = 1 - py0 / H * 2; *y1 = 1 - py1 / H * 2;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        const BOOL any = argc > 1 && !strcmp(argv[1], "--any");
        const uint64_t nmx = nmx_registry_id();
        id<MTLDevice> dev = nil;
        for (id<MTLDevice> d in MTLCopyAllDevices()) {
            const BOOL ours = (nmx && d.registryID == nmx) || [NSStringFromClass([d class]) isEqualToString:@"NVMTLDevice"];
            if (ours || (any && !dev)) dev = d;
            if (ours) break;
        }
        if (!dev) { fprintf(stderr, "FAIL: no B580 Metal device (--any runs on the first device)\n"); return 1; }
        printf("device: %s (%s)\n", dev.name.UTF8String, NSStringFromClass([dev class]).UTF8String);

        NSError *err = nil;
        id<MTLLibrary> lib = [dev newLibraryWithSource:kSource options:[MTLCompileOptions new] error:&err];
        if (!lib) { fprintf(stderr, "FAIL: newLibraryWithSource: %s\n", err.localizedDescription.UTF8String); return 2; }

        MTLRenderPipelineDescriptor *rd = [MTLRenderPipelineDescriptor new];
        rd.vertexFunction = [lib newFunctionWithName:@"vmain"];
        rd.fragmentFunction = [lib newFunctionWithName:@"fmain"];
        rd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        rd.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
        rd.supportIndirectCommandBuffers = YES;
        id<MTLRenderPipelineState> draw = [dev newRenderPipelineStateWithDescriptor:rd error:&err];
        if (!draw) { fprintf(stderr, "FAIL: draw pipeline: %s\n", err.localizedDescription.UTF8String); return 2; }

        MTLRenderPipelineDescriptor *cd = [MTLRenderPipelineDescriptor new];
        id<MTLFunction> vclamp = [lib newFunctionWithName:@"vclamp"];
        cd.vertexFunction = vclamp;
        cd.rasterizationEnabled = NO;
        cd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        cd.inputPrimitiveTopology = MTLPrimitiveTopologyClassPoint;
        id<MTLRenderPipelineState> clamp = [dev newRenderPipelineStateWithDescriptor:cd error:&err];
        if (!clamp) { fprintf(stderr, "FAIL: clamp pipeline: %s\n", err.localizedDescription.UTF8String); return 2; }

        id<MTLFunction> encFn = [lib newFunctionWithName:@"encode"];
        id<MTLComputePipelineState> enc = [dev newComputePipelineStateWithFunction:encFn error:&err];
        if (!enc) { fprintf(stderr, "FAIL: encode pipeline: %s\n", err.localizedDescription.UTF8String); return 2; }

        // vertices: four 4-vertex quads at 4q (quad 0 covers cell 4, quads 1..3 cells 1..3), then cell 0 as a 6-vertex list at 16.
        // Slot 5's CPU draw reuses quad 3 with colour 5: a lost reset paints cell 3 cyan over yellow, which the check sees.
        float verts[22][2];
        for (unsigned q = 0; q < 4; q++) {
            float x0, y0, x1, y1; cell_rect(q ? q : 4, &x0, &y0, &x1, &y1);
            const float c[4][2] = { { x0, y0 }, { x1, y0 }, { x0, y1 }, { x1, y1 } };
            memcpy(verts[4 * q], c, sizeof c);
        }
        { float x0, y0, x1, y1; cell_rect(0, &x0, &y0, &x1, &y1);
          const float l[6][2] = { { x0, y0 }, { x1, y0 }, { x0, y1 }, { x0, y1 }, { x1, y0 }, { x1, y1 } };
          memcpy(verts[16], l, sizeof l); }
        const float colors[SLOTS][4] = { { 1, 0, 0, 1 }, { 0, 1, 0, 1 }, { 0, 0, 1, 1 }, { 1, 1, 0, 1 }, { 1, 0, 1, 1 }, { 0, 1, 1, 1 } };
        // indices: six junk entries, then the quad (the GPU-encoded draws point six indices in, the CPU ones offset 24 bytes)
        const uint32_t i32[12] = { 9, 9, 9, 9, 9, 9, 0, 1, 2, 2, 1, 3 };
        const uint16_t i16[12] = { 9, 9, 9, 9, 9, 9, 0, 1, 2, 2, 1, 3 };
        id<MTLBuffer> vb = [dev newBufferWithBytes:verts length:sizeof verts options:MTLResourceStorageModeShared];
        id<MTLBuffer> cb = [dev newBufferWithBytes:colors length:sizeof colors options:MTLResourceStorageModeShared];
        id<MTLBuffer> ib32 = [dev newBufferWithBytes:i32 length:sizeof i32 options:MTLResourceStorageModeShared];
        id<MTLBuffer> ib16 = [dev newBufferWithBytes:i16 length:sizeof i16 options:MTLResourceStorageModeShared];
        const uint64_t ptrs[2] = { ib32.gpuAddress, ib16.gpuAddress };
        id<MTLBuffer> pb = [dev newBufferWithBytes:ptrs length:sizeof ptrs options:MTLResourceStorageModeShared];

        MTLIndirectCommandBufferDescriptor *idesc = [MTLIndirectCommandBufferDescriptor new];
        idesc.commandTypes = MTLIndirectCommandTypeDraw | MTLIndirectCommandTypeDrawIndexed;
        idesc.inheritPipelineState = YES;
        idesc.inheritBuffers = YES;
        id<MTLIndirectCommandBuffer> icb = [dev newIndirectCommandBufferWithDescriptor:idesc maxCommandCount:SLOTS options:0];
        if (!icb) { fprintf(stderr, "FAIL: newIndirectCommandBufferWithDescriptor\n"); return 2; }

        // the container both encoders read: an argument buffer whose command_buffer field is the ICB
        id<MTLArgumentEncoder> ae = [encFn newArgumentEncoderWithBufferIndex:0];
        id<MTLBuffer> container = [dev newBufferWithLength:ae.encodedLength options:MTLResourceStorageModeShared];
        [ae setArgumentBuffer:container offset:0];
        [ae setIndirectCommandBuffer:icb atIndex:0];

        // CPU-encoded slots (after the ICB went into the container, as WebKit orders it)
        [[icb indirectRenderCommandAtIndex:1] drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:0 indexType:MTLIndexTypeUInt32
                                                      indexBuffer:ib32 indexBufferOffset:0 instanceCount:1 baseVertex:0 baseInstance:1];
        [[icb indirectRenderCommandAtIndex:2] drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:0 indexType:MTLIndexTypeUInt16
                                                      indexBuffer:ib16 indexBufferOffset:0 instanceCount:1 baseVertex:0 baseInstance:2];
        [[icb indirectRenderCommandAtIndex:3] drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt32
                                                      indexBuffer:ib32 indexBufferOffset:24 instanceCount:1 baseVertex:12 baseInstance:3];
        [[icb indirectRenderCommandAtIndex:4] drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt32
                                                      indexBuffer:ib32 indexBufferOffset:24 instanceCount:1 baseVertex:0 baseInstance:4];
        [[icb indirectRenderCommandAtIndex:5] drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt32
                                                      indexBuffer:ib32 indexBufferOffset:24 instanceCount:1 baseVertex:12 baseInstance:5];

        MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:W height:H mipmapped:NO];
        td.usage = MTLTextureUsageRenderTarget; td.storageMode = MTLStorageModePrivate;
        id<MTLTexture> rt = [dev newTextureWithDescriptor:td];
        id<MTLBuffer> out = [dev newBufferWithLength:W * H * 4 options:MTLResourceStorageModeShared];

        id<MTLCommandQueue> q = [dev newCommandQueue];
        id<MTLCommandBuffer> cmd = [q commandBuffer];
        id<MTLComputeCommandEncoder> ce = [cmd computeCommandEncoder];
        [ce setComputePipelineState:enc];
        [ce setBuffer:container offset:0 atIndex:0];
        [ce setBuffer:pb offset:0 atIndex:1];
        [ce useResource:ib32 usage:MTLResourceUsageRead];
        [ce useResource:ib16 usage:MTLResourceUsageRead];
        [ce useResource:icb usage:MTLResourceUsageWrite];
        [ce dispatchThreads:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
        [ce endEncoding];

        MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
        rp.colorAttachments[0].texture = rt; rp.colorAttachments[0].loadAction = MTLLoadActionClear;
        rp.colorAttachments[0].storeAction = MTLStoreActionStore; rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
        id<MTLRenderCommandEncoder> re = [cmd renderCommandEncoderWithDescriptor:rp];
        [re setRenderPipelineState:clamp];
        [re setVertexBuffer:container offset:0 atIndex:0];
        [re setVertexBuffer:pb offset:0 atIndex:1];
        [re useResource:ib32 usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
        [re useResource:icb usage:MTLResourceUsageRead | MTLResourceUsageWrite stages:MTLRenderStageVertex];
        [re drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:1];
        [re memoryBarrierWithScope:MTLBarrierScopeBuffers afterStages:MTLRenderStageVertex beforeStages:MTLRenderStageVertex];
        [re setRenderPipelineState:draw];
        [re setVertexBuffer:vb offset:0 atIndex:0];
        [re setVertexBuffer:cb offset:0 atIndex:1];
        [re useResource:vb usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
        [re useResource:cb usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
        [re useResource:ib32 usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
        [re useResource:ib16 usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
        [re executeCommandsInBuffer:icb withRange:NSMakeRange(0, SLOTS)];
        [re endEncoding];

        id<MTLBlitCommandEncoder> be = [cmd blitCommandEncoder];
        [be copyFromTexture:rt sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(W, H, 1)
                   toBuffer:out destinationOffset:0 destinationBytesPerRow:W * 4 destinationBytesPerImage:W * H * 4];
        [be endEncoding];
        [cmd commit];
        [cmd waitUntilCompleted];
        if (cmd.status != MTLCommandBufferStatusCompleted) {
            fprintf(stderr, "FAIL: command buffer status %ld: %s\n", (long)cmd.status, cmd.error.localizedDescription.UTF8String ?: "");
            return 3;
        }

        // expected: cells 0..3 their colour, 4 and 5 black (cell 3 yellow, not cyan: slot 5's reset held)
        const uint8_t *px = (const uint8_t *)out.contents;
        const uint8_t want[SLOTS][4] = { { 255, 0, 0, 255 }, { 0, 255, 0, 255 }, { 0, 0, 255, 255 }, { 255, 255, 0, 255 },
                                         { 0, 0, 0, 255 }, { 0, 0, 0, 255 } };
        const char *what[SLOTS] = { "GPU draw_primitives", "GPU drawIndexed u32 (first index from the pointer)",
                                    "GPU drawIndexed u16 (first index from the pointer)", "CPU drawIndexed, untouched",
                                    "CPU drawIndexed emptied by a vertex shader (vsICB)", "CPU drawIndexed reset by the kernel" };
        int bad = 0;
        for (unsigned k = 0; k < SLOTS; k++) {
            const unsigned x = (k % 3) * CELL + CELL / 2, y = (k / 3) * CELL + CELL / 2;
            const uint8_t *p = px + (y * W + x) * 4;
            // the cell border (inset 4) stays the clear colour
            const uint8_t *e = px + (((k / 3) * CELL + 1) * W + (k % 3) * CELL + 1) * 4;
            const int ok = !memcmp(p, want[k], 4) && e[0] == 0 && e[1] == 0 && e[2] == 0;
            printf("%s slot %u %-52s centre %3u %3u %3u %3u (want %3u %3u %3u)\n", ok ? "PASS" : "FAIL", k, what[k],
                   p[0], p[1], p[2], p[3], want[k][0], want[k][1], want[k][2]);
            bad += !ok;
        }
        return bad ? 4 : 0;
    }
}
