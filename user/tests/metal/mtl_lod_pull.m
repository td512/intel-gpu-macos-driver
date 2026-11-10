// SPDX-License-Identifier: MIT
// mtl_lod_pull: what -supportsQueryTextureLOD and -supportsPullModelInterpolation promise, drawn on the device.
//   LOD: a 64x64 target covered by one triangle whose coordinates run 0..1 (2D, 2D array, 3D: u, v; cubes: the +X face,
//   -1..1) reads 256-texel textures with 9 levels, so the computed level is log2(256 / 64) = 2 at the target's centre.
//   calculate_clamped_lod and calculate_unclamped_lod are read there for 2D, 2D array, 3D, cube, cube array and the depth
//   2D, 2D array and cube forms; then once more for 2D with a sampler whose lodMaxClamp is 1 (clamped 1, unclamped 2).
//   Pull model: interpolant<float2> and interpolant<half3> inputs read at the centre, at an offset, at sample 0 and at the
//   centroid. Metal's offset counts from the pixel's upper-left corner, so (0.25, 0) is a quarter pixel left of the centre:
//   with u = x / 64 it reads 0.25 / 64 less than the centre (the test scales by 64); (0, 0.25) is a quarter pixel up, and
//   v grows upwards, so the half interpolant reads 0.25 / 64 more (values from the Apple GPU reference run).
//
//   ./mtl_lod_pull          on the B580 (NVMTLDevice)
//   ./mtl_lod_pull --any    on the first Metal device when no B580 is present (reference run)
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <IOKit/IOKitLib.h>
#include <math.h>
#include <string.h>

static NSString *const kSrc = @
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct V { float4 pos [[position]]; float2 uv; };\n"
"vertex V vs(uint i [[vertex_id]]) {\n"
"  float2 p = float2((i << 1) & 2, i & 2);\n"               // (0,0) (2,0) (0,2): covers the target
"  V o; o.pos = float4(p * 2 - 1, 0, 1); o.uv = p; return o; }\n"
"static float3 cdir(float2 uv) { return float3(1, uv.y * 2 - 1, uv.x * 2 - 1); }\n"
"fragment float4 f2d(V i [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  return float4(t.calculate_clamped_lod(s, i.uv), t.calculate_unclamped_lod(s, i.uv), 0, 1); }\n"
"fragment float4 f2da(V i [[stage_in]], texture2d_array<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  return float4(t.calculate_clamped_lod(s, i.uv), t.calculate_unclamped_lod(s, i.uv), 0, 1); }\n"
"fragment float4 f3d(V i [[stage_in]], texture3d<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  float3 c = float3(i.uv, 0.5); return float4(t.calculate_clamped_lod(s, c), t.calculate_unclamped_lod(s, c), 0, 1); }\n"
"fragment float4 fcube(V i [[stage_in]], texturecube<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  float3 c = cdir(i.uv); return float4(t.calculate_clamped_lod(s, c), t.calculate_unclamped_lod(s, c), 0, 1); }\n"
"fragment float4 fcubea(V i [[stage_in]], texturecube_array<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  float3 c = cdir(i.uv); return float4(t.calculate_clamped_lod(s, c), t.calculate_unclamped_lod(s, c), 0, 1); }\n"
"fragment float4 fd2d(V i [[stage_in]], depth2d<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  return float4(t.calculate_clamped_lod(s, i.uv), t.calculate_unclamped_lod(s, i.uv), 0, 1); }\n"
"fragment float4 fd2da(V i [[stage_in]], depth2d_array<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  return float4(t.calculate_clamped_lod(s, i.uv), t.calculate_unclamped_lod(s, i.uv), 0, 1); }\n"
"fragment float4 fdcube(V i [[stage_in]], depthcube<float> t [[texture(0)]], sampler s [[sampler(0)]]) {\n"
"  float3 c = cdir(i.uv); return float4(t.calculate_clamped_lod(s, c), t.calculate_unclamped_lod(s, c), 0, 1); }\n"
"struct P { float4 pos [[position]]; interpolant<float2, interpolation::perspective> uv; interpolant<half3, interpolation::no_perspective> h; };\n"
"struct VP { float4 pos [[position]]; float2 uv; half3 h; };\n"
"vertex VP vsp(uint i [[vertex_id]]) {\n"
"  float2 p = float2((i << 1) & 2, i & 2);\n"
"  VP o; o.pos = float4(p * 2 - 1, 0, 1); o.uv = p; o.h = half3(half2(p), 0); return o; }\n"
"fragment float4 fpull(P i [[stage_in]]) {\n"
"  float2 c = i.uv.interpolate_at_center();\n"
"  float a = (i.uv.interpolate_at_offset(float2(0.25, 0)).x - c.x) * 64;\n"
"  float b = (i.uv.interpolate_at_centroid().x - c.x) * 64;\n"
"  float d = (float(i.h.interpolate_at_offset(float2(0, 0.25)).y) - float(i.h.interpolate_at_center().y)) * 64;\n"
"  float e = (i.uv.interpolate_at_sample(0).y - c.y) * 64;\n"
"  return float4(a, b, d, e); }\n";

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

static id<MTLTexture> tex(id<MTLDevice> d, MTLTextureType type, MTLPixelFormat f)
{
    MTLTextureDescriptor *td = [MTLTextureDescriptor new];
    td.textureType = type; td.pixelFormat = f; td.width = td.height = 256; td.mipmapLevelCount = 9;
    td.depth = type == MTLTextureType3D ? 4 : 1;
    td.arrayLength = (type == MTLTextureType2DArray || type == MTLTextureTypeCubeArray) ? 2 : 1;
    td.storageMode = MTLStorageModePrivate; td.usage = MTLTextureUsageShaderRead;
    return [d newTextureWithDescriptor:td];
}

// draws `frag` over the 64x64 RGBA32Float target and returns the centre texel
static BOOL draw(id<MTLDevice> d, id<MTLCommandQueue> q, id<MTLLibrary> l, NSString *vert, NSString *frag, id<MTLTexture> t,
                 id<MTLSamplerState> s, float out[4])
{
    NSError *e = nil;
    MTLRenderPipelineDescriptor *pd = [MTLRenderPipelineDescriptor new];
    pd.vertexFunction = [l newFunctionWithName:vert]; pd.fragmentFunction = [l newFunctionWithName:frag];
    pd.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
    id<MTLRenderPipelineState> p = pd.vertexFunction && pd.fragmentFunction ? [d newRenderPipelineStateWithDescriptor:pd error:&e] : nil;
    if (!p) { printf("  %-7s pipeline FAILED: %s\n", frag.UTF8String, e.localizedDescription.UTF8String ?: "no function"); return NO; }
    MTLTextureDescriptor *rd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float width:64 height:64 mipmapped:NO];
    rd.usage = MTLTextureUsageRenderTarget;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    const BOOL managed = !d.hasUnifiedMemory;   // a discrete GPU (the B580) reads back a Managed target
    rd.storageMode = managed ? MTLStorageModeManaged : MTLStorageModeShared;
    id<MTLTexture> rt = [d newTextureWithDescriptor:rd];
    MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
    rp.colorAttachments[0].texture = rt; rp.colorAttachments[0].loadAction = MTLLoadActionClear;
    rp.colorAttachments[0].clearColor = MTLClearColorMake(-9, -9, -9, -9); rp.colorAttachments[0].storeAction = MTLStoreActionStore;
    id<MTLCommandBuffer> cb = [q commandBuffer];
    id<MTLRenderCommandEncoder> en = [cb renderCommandEncoderWithDescriptor:rp];
    [en setRenderPipelineState:p];
    if (t) [en setFragmentTexture:t atIndex:0];
    if (s) [en setFragmentSamplerState:s atIndex:0];
    [en drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3]; [en endEncoding];
    if (managed) { id<MTLBlitCommandEncoder> bl = [cb blitCommandEncoder]; [bl synchronizeResource:rt]; [bl endEncoding]; }
#pragma clang diagnostic pop
    [cb commit]; [cb waitUntilCompleted];
    if (cb.error) { printf("  %-7s command buffer error: %s\n", frag.UTF8String, cb.error.localizedDescription.UTF8String); return NO; }
    [rt getBytes:out bytesPerRow:64 * 16 fromRegion:MTLRegionMake2D(32, 32, 1, 1) mipmapLevel:0];
    return YES;
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
        printf("supportsQueryTextureLOD %d, supportsPullModelInterpolation %d\n", dev.supportsQueryTextureLOD, dev.supportsPullModelInterpolation);
        CHECK(dev.supportsQueryTextureLOD, "supportsQueryTextureLOD is NO");
        CHECK(dev.supportsPullModelInterpolation, "supportsPullModelInterpolation is NO");
        NSError *e = nil;
        id<MTLLibrary> l = [dev newLibraryWithSource:kSrc options:nil error:&e];
        if (!l) { printf("FAIL: library: %s\n", e.localizedDescription.UTF8String); return 2; }
        id<MTLCommandQueue> q = [dev newCommandQueue];
        MTLSamplerDescriptor *sd = [MTLSamplerDescriptor new];
        sd.minFilter = sd.magFilter = MTLSamplerMinMagFilterLinear; sd.mipFilter = MTLSamplerMipFilterLinear;
        id<MTLSamplerState> s = [dev newSamplerStateWithDescriptor:sd];
        sd.lodMaxClamp = 1; id<MTLSamplerState> s1 = [dev newSamplerStateWithDescriptor:sd];
        const struct { const char *frag; MTLTextureType type; MTLPixelFormat f; } shapes[] = {
            { "f2d", MTLTextureType2D, MTLPixelFormatRGBA8Unorm }, { "f2da", MTLTextureType2DArray, MTLPixelFormatRGBA8Unorm },
            { "f3d", MTLTextureType3D, MTLPixelFormatRGBA8Unorm }, { "fcube", MTLTextureTypeCube, MTLPixelFormatRGBA8Unorm },
            { "fcubea", MTLTextureTypeCubeArray, MTLPixelFormatRGBA8Unorm }, { "fd2d", MTLTextureType2D, MTLPixelFormatDepth32Float },
            { "fd2da", MTLTextureType2DArray, MTLPixelFormatDepth32Float }, { "fdcube", MTLTextureTypeCube, MTLPixelFormatDepth32Float } };
        printf("LOD at the centre (want clamped 2, unclamped 2):\n");
        for (size_t k = 0; k < sizeof shapes / sizeof shapes[0]; k++) {
            float r[4] = { NAN, NAN, NAN, NAN };
            id<MTLTexture> t = tex(dev, shapes[k].type, shapes[k].f);
            if (!t) { printf("  %-7s texture refused\n", shapes[k].frag); g_bad++; continue; }
            if (!draw(dev, q, l, @"vs", @(shapes[k].frag), t, s, r)) { g_bad++; continue; }
            const BOOL ok = fabsf(r[0] - 2) < 0.1f && fabsf(r[1] - 2) < 0.1f;
            printf("  %s %-7s clamped %.3f unclamped %.3f\n", ok ? "PASS" : "FAIL", shapes[k].frag, r[0], r[1]);
            g_bad += !ok;
        }
        {   // lodMaxClamp 1: the clamped level stops at 1, the unclamped one does not
            float r[4] = { NAN, NAN, NAN, NAN };
            if (draw(dev, q, l, @"vs", @"f2d", tex(dev, MTLTextureType2D, MTLPixelFormatRGBA8Unorm), s1, r)) {
                const BOOL ok = fabsf(r[0] - 1) < 0.1f && fabsf(r[1] - 2) < 0.1f;
                printf("  %s f2d lodMaxClamp 1: clamped %.3f (want 1) unclamped %.3f (want 2)\n", ok ? "PASS" : "FAIL", r[0], r[1]);
                g_bad += !ok;
            } else g_bad++;
        }
        {   // pull model, scaled by the target's width: offset (0.25, 0) -> -0.25, half (0, 0.25) -> 0.25, centroid and sample 0
            // of a 1x target -> 0
            float r[4] = { NAN, NAN, NAN, NAN };
            if (draw(dev, q, l, @"vsp", @"fpull", nil, nil, r)) {
                const BOOL ok = fabsf(r[0] + 0.25f) < 0.01f && fabsf(r[1]) < 0.01f && fabsf(r[2] - 0.25f) < 0.07f && fabsf(r[3]) < 0.01f;
                printf("  %s pull model: offset %.4f (want -0.25), centroid %.4f (want 0), half offset %.4f (want 0.25), sample 0 %.4f (want 0)\n",
                       ok ? "PASS" : "FAIL", r[0], r[1], r[2], r[3]);
                g_bad += !ok;
            } else g_bad++;
        }
        printf("%s (%d failure(s))\n", g_bad ? "FAIL" : "PASS", g_bad);
        return g_bad ? 4 : 0;
    }
}
