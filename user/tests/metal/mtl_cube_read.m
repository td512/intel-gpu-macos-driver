// SPDX-License-Identifier: MIT
// mtl_cube_read: texel reads (read(coord, face[, slice], lod)) of cube and cube-array textures on the Arc B580.
//
// Every texel of every face, slice and mip level is filled with its own address, a compute kernel reads each one back
// with read() into a buffer, and every value is compared. Cases:
//   cube float    texturecube<float, access::read>         RGBA32Float, 16x16, 3 levels (sampled view, centre sample)
//   cube uint     texturecube<uint, access::read>          RGBA32Uint: a linear filter here would blend integers
//   cube array    texturecube_array<float, access::read>   RGBA32Float, 2 cubes, 3 levels
//   cube rw       texturecube<float, access::read_write>   RGBA32Float, level 0 (storage view, OpImageRead x,y,face)
// A texel holds (x, y, face + 10 * slice, level); a wrong face, slice, level or filter shows in the failing component.
//
//   NVMTL_ENABLE=1 ./mtl_cube_read          (NVMTL_ENABLE passes the plugin's allow-list)
//   ./mtl_cube_read --any                   run on the first Metal device when no B580 is present (reference run)
//
// Exit: 0 pass, 1 no B580 device, 2 compile/pipeline failure, 3 GPU error, 4 wrong values.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <IOKit/IOKitLib.h>
#include <stdio.h>
#include <string.h>

static NSString *const kSource =
    @"#include <metal_stdlib>\n"
     "using namespace metal;\n"
     "struct P { uint w, h, lod, pad; };\n"
     "kernel void rd_cube(texturecube<float, access::read> t [[texture(0)]], device float4 *o [[buffer(0)]],\n"
     "                    constant P &p [[buffer(1)]], uint3 g [[thread_position_in_grid]]) {\n"
     "    if (g.x >= p.w || g.y >= p.h) return;\n"
     "    o[(g.z * p.h + g.y) * p.w + g.x] = t.read(g.xy, g.z, p.lod);\n"
     "}\n"
     "kernel void rd_cube_u(texturecube<uint, access::read> t [[texture(0)]], device uint4 *o [[buffer(0)]],\n"
     "                      constant P &p [[buffer(1)]], uint3 g [[thread_position_in_grid]]) {\n"
     "    if (g.x >= p.w || g.y >= p.h) return;\n"
     "    o[(g.z * p.h + g.y) * p.w + g.x] = t.read(g.xy, g.z, p.lod);\n"
     "}\n"
     "kernel void rd_cube_arr(texturecube_array<float, access::read> t [[texture(0)]], device float4 *o [[buffer(0)]],\n"
     "                        constant P &p [[buffer(1)]], uint3 g [[thread_position_in_grid]]) {\n"
     "    if (g.x >= p.w || g.y >= p.h) return;\n"
     "    o[(g.z * p.h + g.y) * p.w + g.x] = t.read(g.xy, g.z % 6, g.z / 6, p.lod);\n"
     "}\n"
     "kernel void rd_cube_rw(texturecube<float, access::read_write> t [[texture(0)]], device float4 *o [[buffer(0)]],\n"
     "                       constant P &p [[buffer(1)]], uint3 g [[thread_position_in_grid]]) {\n"
     "    if (g.x >= p.w || g.y >= p.h) return;\n"
     "    o[(g.z * p.h + g.y) * p.w + g.x] = t.read(g.xy, g.z);\n"
     "}\n";

enum { kSize = 16, kLevels = 3, kCubes = 2 };
typedef struct { uint32_t w, h, lod, pad; } Params;

static uint64_t nmx_registry_id(void)
{
    io_service_t s = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("NMXAccel"));
    if (!s) return 0;
    uint64_t id = 0;
    IORegistryEntryGetRegistryEntryID(s, &id);
    IOObjectRelease(s);
    return id;
}

// one case: a texture of `type`, `cubes` cubes (cube array) or one, `levels` levels read, kernel `fn`
static int run_case(id<MTLDevice> dev, id<MTLLibrary> lib, id<MTLCommandQueue> q, const char *label, NSString *fn,
                    MTLTextureType type, MTLPixelFormat fmt, MTLTextureUsage usage, unsigned cubes, unsigned levels)
{
    NSError *err = nil;
    id<MTLFunction> f = [lib newFunctionWithName:fn];
    id<MTLComputePipelineState> pso = f ? [dev newComputePipelineStateWithFunction:f error:&err] : nil;
    if (!pso) { fprintf(stderr, "FAIL %-11s pipeline: %s\n", label, err ? err.localizedDescription.UTF8String : "no function"); return 2; }

    MTLTextureDescriptor *d = [MTLTextureDescriptor new];
    d.textureType = type; d.pixelFormat = fmt; d.width = kSize; d.height = kSize;
    d.mipmapLevelCount = levels; d.usage = usage;
    if (type == MTLTextureTypeCubeArray) d.arrayLength = cubes;
    id<MTLTexture> tex = [dev newTextureWithDescriptor:d];
    if (!tex) { fprintf(stderr, "FAIL %-11s newTextureWithDescriptor\n", label); return 3; }
    const BOOL integer = fmt == MTLPixelFormatRGBA32Uint;
    for (unsigned level = 0; level < levels; level++) {
        const unsigned w = kSize >> level;
        for (unsigned slice = 0; slice < cubes * 6; slice++) {
            float fv[kSize * kSize * 4]; uint32_t uv[kSize * kSize * 4];
            for (unsigned y = 0; y < w; y++)
                for (unsigned x = 0; x < w; x++) {
                    const uint32_t c[4] = { x, y, slice % 6 + 10 * (slice / 6), level };
                    for (int k = 0; k < 4; k++) { fv[(y * w + x) * 4 + k] = (float)c[k]; uv[(y * w + x) * 4 + k] = c[k]; }
                }
            [tex replaceRegion:MTLRegionMake2D(0, 0, w, w) mipmapLevel:level slice:slice
                     withBytes:integer ? (const void *)uv : (const void *)fv bytesPerRow:w * 16 bytesPerImage:w * w * 16];
        }
    }

    int bad = 0;
    for (unsigned level = 0; level < levels; level++) {
        const unsigned w = kSize >> level, n = w * w * 6 * cubes;
        id<MTLBuffer> out = [dev newBufferWithLength:n * 16 options:MTLResourceStorageModeShared];
        memset(out.contents, 0xA5, n * 16);
        Params p = { w, w, level, 0 };
        id<MTLCommandBuffer> cb = [q commandBuffer];
        id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
        [enc setComputePipelineState:pso];
        [enc setTexture:tex atIndex:0];
        [enc setBuffer:out offset:0 atIndex:0];
        [enc setBytes:&p length:sizeof p atIndex:1];
        [enc dispatchThreads:MTLSizeMake(w, w, 6 * cubes) threadsPerThreadgroup:MTLSizeMake(MIN(w, 8u), MIN(w, 8u), 1)];
        [enc endEncoding];
        [cb commit];
        [cb waitUntilCompleted];
        if (cb.status != MTLCommandBufferStatusCompleted) {
            fprintf(stderr, "FAIL %-11s level %u: command buffer status %ld: %s\n", label, level, (long)cb.status,
                    cb.error.localizedDescription.UTF8String);
            return 3;
        }
        const float *fo = out.contents; const uint32_t *uo = out.contents;
        unsigned wrong = 0;
        for (unsigned z = 0; z < 6 * cubes; z++)
            for (unsigned y = 0; y < w; y++)
                for (unsigned x = 0; x < w; x++) {
                    const unsigned i = ((z * w + y) * w + x) * 4;
                    const uint32_t want[4] = { x, y, z % 6 + 10 * (z / 6), level };
                    uint32_t got[4];
                    for (int k = 0; k < 4; k++) got[k] = integer ? uo[i + k] : (uint32_t)fo[i + k];
                    BOOL same = YES;
                    for (int k = 0; k < 4; k++) same &= got[k] == want[k] && (integer || fo[i + k] == (float)want[k]);
                    if (!same && wrong++ < 6)
                        fprintf(stderr, "  %-11s level %u face %u slice %u (%u,%u): got (%g %g %g %g), want (%u %u %u %u)\n",
                                label, level, z % 6, z / 6, x, y,
                                integer ? (double)uo[i] : fo[i], integer ? (double)uo[i + 1] : fo[i + 1],
                                integer ? (double)uo[i + 2] : fo[i + 2], integer ? (double)uo[i + 3] : fo[i + 3],
                                want[0], want[1], want[2], want[3]);
                }
        printf("%s %-11s level %u: %u of %u texels wrong\n", wrong ? "FAIL" : "PASS", label, level, wrong, n);
        bad += wrong != 0;
    }
    return bad ? 4 : 0;
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
        id<MTLCommandQueue> q = [dev newCommandQueue];

        int rc = 0, r;
        r = run_case(dev, lib, q, "cube float", @"rd_cube", MTLTextureTypeCube, MTLPixelFormatRGBA32Float,
                     MTLTextureUsageShaderRead, 1, kLevels); rc = MAX(rc, r);
        r = run_case(dev, lib, q, "cube uint", @"rd_cube_u", MTLTextureTypeCube, MTLPixelFormatRGBA32Uint,
                     MTLTextureUsageShaderRead, 1, kLevels); rc = MAX(rc, r);
        r = run_case(dev, lib, q, "cube array", @"rd_cube_arr", MTLTextureTypeCubeArray, MTLPixelFormatRGBA32Float,
                     MTLTextureUsageShaderRead, kCubes, kLevels); rc = MAX(rc, r);
        r = run_case(dev, lib, q, "cube rw", @"rd_cube_rw", MTLTextureTypeCube, MTLPixelFormatRGBA32Float,
                     MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite, 1, 1); rc = MAX(rc, r);
        printf("%s\n", rc ? "FAIL" : "PASS: every cube texel read returned its own texel");
        return rc;
    }
}
