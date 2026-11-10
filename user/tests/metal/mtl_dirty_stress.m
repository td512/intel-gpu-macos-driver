// SPDX-License-Identifier: MIT
// mtl_dirty_stress: the Metal plugin's dirty-only bindings (unchanged descriptors copied from the last set, unchanged
// argument-buffer tables skipped; nvmtl_dirty.h) under texture churn, checked pixel by pixel. Runs on any Metal device
// (an Apple GPU gives the reference: 0 failures), and on the B580 through the plugin.
//
// Per frame, into a 256x256 target, 16x16 quads of 16x16 pixels, each sampling one solid-colour texture from a pool of 64
// (every fourth an IOSurface texture); a few pool textures are released and made again every frame, so new objects get
// old addresses. Each quad is drawn with one to three pipelines in turn without rebinding anything (fa, fb, fc read
// different texture / sampler / buffer slots, so a switch builds a new set that copies the unchanged descriptors from the
// last one); the last quarter of the grid samples through an argument buffer (fab), whose entries are rewritten to new
// textures between frames; a compute pass writes a colour through storage texture 70 (binding index 263, past 256) with
// two kernels in turn. Every quad's centre pixel and every compute output must be the colour of the texture it read.
// The white blocks / stale wallpaper seen in Safari on 2026-11-10 were this kind of stale descriptor (NVMTL_NO_DIRTYONLY=1
// hid them).
//
// Build (an Apple GPU: drop -arch x86_64):
//   clang -fobjc-arc -O2 -arch x86_64 -o mtl_dirty_stress mtl_dirty_stress.m -framework Foundation -framework Metal \
//     -framework IOSurface -framework IOKit
// Run: ./mtl_dirty_stress [frames=600] [recycled per frame=8]
//   a plugin build that is not installed: NVMTL_ENABLE=1 NVMTL_BUNDLE=<dir>/NVMTLDriver.bundle ./mtl_dirty_stress
//   A/B: the same with NVMTL_NO_DIRTYONLY=1 (copies and skips off) must also pass.
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>
#import <objc/message.h>
#include <stdlib.h>

static NSString *const kSource = @R"(
#include <metal_stdlib>
using namespace metal;
struct VOut { float4 pos [[position]]; float2 uv; };
vertex VOut vq(uint vid [[vertex_id]], constant float4 &r [[buffer(0)]]) {
    const float2 c[4] = { float2(r.x, r.y), float2(r.z, r.y), float2(r.x, r.w), float2(r.z, r.w) };
    VOut o; o.pos = float4(c[vid], 0.0, 1.0); o.uv = float2(float(vid & 1u), float(vid >> 1)); return o;
}
fragment float4 fa(VOut in [[stage_in]], texture2d<float> t0 [[texture(0)]], sampler s0 [[sampler(0)]]) {
    return t0.sample(s0, in.uv);
}
fragment float4 fb(VOut in [[stage_in]], texture2d<float> t0 [[texture(0)]], texture2d<float> t5 [[texture(5)]],
                   sampler s0 [[sampler(0)]], sampler s3 [[sampler(3)]], constant float &k [[buffer(0)]]) {
    return t0.sample(s0, in.uv) + k * t5.sample(s3, in.uv);
}
fragment float4 fc(VOut in [[stage_in]], texture2d<float> t0 [[texture(0)]], texture2d<float> t9 [[texture(9)]],
                   constant float &k [[buffer(0)]]) {
    return t0.read(uint2(1, 1)) + k * t9.read(uint2(0, 0));
}
struct Args { texture2d<float> t [[id(0)]]; };
fragment float4 fab(VOut in [[stage_in]], constant Args &a [[buffer(1)]], sampler s0 [[sampler(0)]]) {
    return a.t.sample(s0, in.uv);
}
kernel void ka(texture2d<float, access::read> src [[texture(0)]], texture2d<float, access::write> dst [[texture(70)]],
               uint2 g [[thread_position_in_grid]]) {
    dst.write(src.read(uint2(0, 0)), g);
}
kernel void kb(texture2d<float, access::read> src [[texture(0)]], texture2d<float, access::read> x [[texture(5)]],
               texture2d<float, access::write> dst [[texture(70)]], constant float &k [[buffer(0)]],
               uint2 g [[thread_position_in_grid]]) {
    dst.write(src.read(uint2(1, 1)) + k * x.read(uint2(0, 0)), g);
}
)";

enum { W = 256, Q = 16, NQ = 16, NT = 64, TS = 8, NDST = 8, ABROWS = 4 };

static id<MTLDevice> bundleDevice(const char *path) {   // as mtl_order_stress.m: that plugin build in this process only
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

typedef struct { uint8_t r, g, b; } rgb;
static rgb colourOf(uint32_t id) { return (rgb){ (uint8_t)(id * 37u + 11u), (uint8_t)(id * 91u + 50u), (uint8_t)(id * 53u + 100u) }; }

static id<MTLDevice> gDev;
static uint32_t gNextColour = 1;
// A solid TSxTS texture of a new colour; every fourth one on an IOSurface (BGRA, as CoreAnimation's are)
static id<MTLTexture> makeTexture(uint32_t *colourId, BOOL surface) {
    const uint32_t cid = gNextColour++; *colourId = cid;
    const rgb c = colourOf(cid);
    uint8_t px[TS * TS * 4];
    if (surface) {
        NSDictionary *props = @{ (id)kIOSurfaceWidth: @(TS), (id)kIOSurfaceHeight: @(TS), (id)kIOSurfaceBytesPerElement: @4,
                                 (id)kIOSurfacePixelFormat: @((uint32_t)'BGRA') };
        IOSurfaceRef s = IOSurfaceCreate((__bridge CFDictionaryRef)props);
        if (!s) return nil;
        IOSurfaceLock(s, 0, NULL);
        uint8_t *base = IOSurfaceGetBaseAddress(s); const size_t row = IOSurfaceGetBytesPerRow(s);
        for (int y = 0; y < TS; y++) for (int x = 0; x < TS; x++) { uint8_t *p = base + y * row + x * 4; p[0] = c.b; p[1] = c.g; p[2] = c.r; p[3] = 255; }
        IOSurfaceUnlock(s, 0, NULL);
        MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:TS height:TS mipmapped:NO];
        d.usage = MTLTextureUsageShaderRead; d.storageMode = MTLStorageModeShared;
        id<MTLTexture> t = [gDev newTextureWithDescriptor:d iosurface:s plane:0];
        CFRelease(s);
        return t;
    }
    for (int i = 0; i < TS * TS; i++) { px[i * 4] = c.r; px[i * 4 + 1] = c.g; px[i * 4 + 2] = c.b; px[i * 4 + 3] = 255; }
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:TS height:TS mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> t = [gDev newTextureWithDescriptor:d];
    [t replaceRegion:MTLRegionMake2D(0, 0, TS, TS) mipmapLevel:0 withBytes:px bytesPerRow:TS * 4];
    return t;
}

static long gFail[3]; static const char *const kWhat[3] = { "draw", "argument buffer", "compute (storage texture 70)" };
static int near(uint8_t a, uint8_t b) { return a > b ? a - b <= 1 : b - a <= 1; }
static void expect(int what, int frame, int idx, const uint8_t *got, rgb want, BOOL surface, const char *pipes) {
    if (near(got[0], want.r) && near(got[1], want.g) && near(got[2], want.b)) return;
    if (gFail[0] + gFail[1] + gFail[2] < 30)
        printf("FAIL frame %d %s %d (%s texture, pipelines %s): got %u,%u,%u want %u,%u,%u\n", frame, kWhat[what], idx,
               surface ? "IOSurface" : "plain", pipes, got[0], got[1], got[2], want.r, want.g, want.b);
    gFail[what]++;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IOLBF, 0);
        const int frames = argc > 1 ? atoi(argv[1]) : 600, recycle = argc > 2 ? atoi(argv[2]) : 8;
        const char *bundle = getenv("NVMTL_BUNDLE");
        if (bundle) gDev = bundleDevice(bundle);
        if (!gDev) for (id<MTLDevice> d in MTLCopyAllDevices()) if ([NSStringFromClass([d class]) isEqualToString:@"NVMTLDevice"]) gDev = d;
        if (!gDev) gDev = MTLCreateSystemDefaultDevice();
        if (!gDev) { printf("no Metal device\n"); return 2; }
        printf("device %s (%s), %d frames, %d textures remade per frame, NVMTL_NO_DIRTYONLY=%s\n", gDev.name.UTF8String,
               NSStringFromClass([gDev class]).UTF8String, frames, recycle, getenv("NVMTL_NO_DIRTYONLY") ?: "unset");
        NSError *e = nil;
        id<MTLLibrary> lib = [gDev newLibraryWithSource:kSource options:nil error:&e];
        if (!lib) { printf("library: %s\n", e.description.UTF8String); return 2; }
        id<MTLFunction> vq = [lib newFunctionWithName:@"vq"], fabFn = [lib newFunctionWithName:@"fab"];
        id<MTLRenderPipelineState> pipe[4];
        NSString *const names[4] = { @"fa", @"fb", @"fc", @"fab" };
        for (int i = 0; i < 4; i++) {
            MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new];
            d.vertexFunction = vq; d.fragmentFunction = i == 3 ? fabFn : [lib newFunctionWithName:names[i]];
            d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
            pipe[i] = [gDev newRenderPipelineStateWithDescriptor:d error:&e];
            if (!pipe[i]) { printf("pipeline %s: %s\n", names[i].UTF8String, e.description.UTF8String); return 2; }
        }
        id<MTLComputePipelineState> ka = [gDev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"ka"] error:&e];
        id<MTLComputePipelineState> kb = [gDev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"kb"] error:&e];
        if (!ka || !kb) { printf("kernels: %s\n", e.description.UTF8String); return 2; }

        MTLTextureDescriptor *rd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:W height:W mipmapped:NO];
        rd.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead; rd.storageMode = MTLStorageModePrivate;
        id<MTLTexture> rt = [gDev newTextureWithDescriptor:rd];
        id<MTLTexture> dst[NDST];
        MTLTextureDescriptor *dd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:Q height:Q mipmapped:NO];
        dd.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead; dd.storageMode = MTLStorageModePrivate;
        for (int i = 0; i < NDST; i++) dst[i] = [gDev newTextureWithDescriptor:dd];
        id<MTLBuffer> rb = [gDev newBufferWithLength:W * W * 4 options:MTLResourceStorageModeShared];
        id<MTLBuffer> db = [gDev newBufferWithLength:NDST * Q * Q * 4 options:MTLResourceStorageModeShared];
        MTLSamplerDescriptor *sd = [MTLSamplerDescriptor new];
        sd.minFilter = sd.magFilter = MTLSamplerMinMagFilterNearest;
        id<MTLSamplerState> s0 = [gDev newSamplerStateWithDescriptor:sd];
        sd.sAddressMode = sd.tAddressMode = MTLSamplerAddressModeRepeat;
        id<MTLSamplerState> s3 = [gDev newSamplerStateWithDescriptor:sd];
        uint32_t zeroId; id<MTLTexture> zero = makeTexture(&zeroId, NO);   // read with k = 0: only keeps slots 5 / 9 in the masks

        id<MTLTexture> pool[NT]; uint32_t poolColour[NT]; BOOL poolSurf[NT];
        for (int i = 0; i < NT; i++) { poolSurf[i] = (i & 3) == 3; pool[i] = makeTexture(&poolColour[i], poolSurf[i]); if (!pool[i]) { printf("texture %d FAILED\n", i); return 2; } }
        // argument buffers: one entry per quad of the last ABROWS rows
        id<MTLArgumentEncoder> ae = [fabFn newArgumentEncoderWithBufferIndex:1];
        const NSUInteger abStride = (ae.encodedLength + 255) & ~(NSUInteger)255, nab = ABROWS * NQ;
        id<MTLBuffer> ab = [gDev newBufferWithLength:abStride * nab options:MTLResourceStorageModeShared];
        int abTex[ABROWS * NQ];
        for (NSUInteger q = 0; q < nab; q++) { abTex[q] = (int)(q * 5 % NT); [ae setArgumentBuffer:ab offset:q * abStride]; [ae setTexture:pool[abTex[q]] atIndex:0]; }
        id<MTLCommandQueue> queue = [gDev newCommandQueue];
        const float k0 = 0.0f;
        srand(7);
        long checked = 0;
        for (int f = 0; f < frames; f++) @autoreleasepool {
            // new objects at old addresses: the pool textures go (the last frame has completed) and others come
            for (int r = 0; r < recycle; r++) { const int i = rand() % NT; pool[i] = nil; pool[i] = makeTexture(&poolColour[i], poolSurf[i]); }
            // argument entries: those naming a remade texture name it again (same offset, new handle), a few move
            for (NSUInteger q = 0; q < nab; q++) {
                if (rand() % 8 == 0) abTex[q] = rand() % NT;
                [ae setArgumentBuffer:ab offset:q * abStride]; [ae setTexture:pool[abTex[q]] atIndex:0];
            }
            id<MTLCommandBuffer> cb = [queue commandBuffer];
            MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor new];
            rp.colorAttachments[0].texture = rt; rp.colorAttachments[0].loadAction = MTLLoadActionClear;
            rp.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1); rp.colorAttachments[0].storeAction = MTLStoreActionStore;
            id<MTLRenderCommandEncoder> re = [cb renderCommandEncoderWithDescriptor:rp];
            [re setFragmentBytes:&k0 length:4 atIndex:0];
            [re setFragmentSamplerState:s0 atIndex:0]; [re setFragmentSamplerState:s3 atIndex:3];
            [re setFragmentTexture:zero atIndex:5]; [re setFragmentTexture:zero atIndex:9];
            int quadTex[NQ * NQ]; char quadPipes[NQ * NQ][8];
            static const char *const orders[6] = { "a", "ab", "bc", "cab", "ca", "bab" };
            for (int q = 0; q < NQ * NQ; q++) {
                const int row = q / NQ, col = q % NQ;
                const float x0 = -1.f + col * 2.f / NQ, yt = 1.f - row * 2.f / NQ;
                const float rect[4] = { x0, yt - 2.f / NQ, x0 + 2.f / NQ, yt };
                [re setVertexBytes:rect length:sizeof rect atIndex:0];
                if (row >= NQ - ABROWS) {
                    // through the argument buffer; every third quad first draws with fa and another texture in slot 0
                    const int a = (row - (NQ - ABROWS)) * NQ + col;
                    if (q % 3 == 0) { [re setRenderPipelineState:pipe[0]]; [re setFragmentTexture:pool[(q * 11) % NT] atIndex:0];
                                      [re drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4]; }
                    [re useResource:pool[abTex[a]] usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
                    [re setRenderPipelineState:pipe[3]];
                    [re setFragmentBuffer:ab offset:(NSUInteger)a * abStride atIndex:1];
                    [re drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
                    quadTex[q] = abTex[a]; snprintf(quadPipes[q], sizeof quadPipes[q], "%sab", q % 3 == 0 ? "a," : "");
                    continue;
                }
                const int t = (q * 7 + f * 13) % NT; quadTex[q] = t;
                [re setFragmentTexture:pool[t] atIndex:0];
                const char *o = orders[(q + f) % 6]; snprintf(quadPipes[q], sizeof quadPipes[q], "%s", o);
                for (const char *c = o; *c; c++) {   // the same quad again with the next pipeline, nothing rebound
                    [re setRenderPipelineState:pipe[*c - 'a']];
                    [re drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
                }
            }
            [re endEncoding];
            id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
            int dstTex[NDST];
            for (int i = 0; i < NDST; i++) {
                dstTex[i] = (i * 9 + f * 5) % NT;
                [ce setTexture:pool[dstTex[i]] atIndex:0]; [ce setTexture:zero atIndex:5]; [ce setTexture:dst[i] atIndex:70];
                [ce setBytes:&k0 length:4 atIndex:0];
                [ce setComputePipelineState:(i & 1) ? kb : ka];
                [ce dispatchThreads:MTLSizeMake(Q, Q, 1) threadsPerThreadgroup:MTLSizeMake(8, 8, 1)];
                [ce setComputePipelineState:(i & 1) ? ka : kb];   // the other kernel, nothing rebound
                [ce dispatchThreads:MTLSizeMake(Q, Q, 1) threadsPerThreadgroup:MTLSizeMake(8, 8, 1)];
            }
            [ce endEncoding];
            id<MTLBlitCommandEncoder> be = [cb blitCommandEncoder];
            [be copyFromTexture:rt sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(W, W, 1)
                       toBuffer:rb destinationOffset:0 destinationBytesPerRow:W * 4 destinationBytesPerImage:W * W * 4];
            for (int i = 0; i < NDST; i++)
                [be copyFromTexture:dst[i] sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(Q, Q, 1)
                           toBuffer:db destinationOffset:(NSUInteger)i * Q * Q * 4 destinationBytesPerRow:Q * 4 destinationBytesPerImage:Q * Q * 4];
            [be endEncoding];
            [cb commit]; [cb waitUntilCompleted];
            if (cb.status != MTLCommandBufferStatusCompleted) { printf("frame %d: command buffer status %ld error %s\n", f, (long)cb.status, cb.error.description.UTF8String); return 2; }
            const uint8_t *px = rb.contents;
            for (int q = 0; q < NQ * NQ; q++) {
                const int row = q / NQ, col = q % NQ;
                const uint8_t *p = px + ((row * Q + Q / 2) * W + col * Q + Q / 2) * 4;
                expect(row >= NQ - ABROWS ? 1 : 0, f, q, p, colourOf(poolColour[quadTex[q]]), poolSurf[quadTex[q]], quadPipes[q]); checked++;
            }
            const uint8_t *dp = db.contents;
            for (int i = 0; i < NDST; i++) { expect(2, f, i, dp + ((size_t)i * Q * Q + (Q / 2) * Q + Q / 2) * 4, colourOf(poolColour[dstTex[i]]), poolSurf[dstTex[i]], (i & 1) ? "kb,ka" : "ka,kb"); checked++; }
            if ((f + 1) % 100 == 0) printf("frame %d: %ld failures so far\n", f + 1, gFail[0] + gFail[1] + gFail[2]);
        }
        printf("%ld pixels checked: %ld draw, %ld argument-buffer, %ld compute failures -> %s\n", checked, gFail[0], gFail[1], gFail[2],
               gFail[0] + gFail[1] + gFail[2] ? "FAIL" : "PASS");
        return gFail[0] + gFail[1] + gFail[2] ? 1 : 0;
    }
}
