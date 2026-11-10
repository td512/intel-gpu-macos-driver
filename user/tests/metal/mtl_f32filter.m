// SPDX-License-Identifier: MIT
// mtl_f32filter: linear filtering of R32Float / RG32Float / RGBA32Float textures (what supports32BitFloatFiltering promises):
// a 2x1 texture (0, 1) sampled at u = 0.5 (between the texel centres) must give 0.5.
#import <Metal/Metal.h>
static NSString *const kSrc = @"#include <metal_stdlib>\nusing namespace metal;\n"
 "kernel void k(texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]], device float4 *o [[buffer(0)]], uint i [[thread_position_in_grid]]) {\n"
 "  o[i] = t.sample(s, float2(0.25 + 0.25 * float(i), 0.5)); }\n";
int main(void) { @autoreleasepool {
  id<MTLDevice> d = nil; for (id<MTLDevice> x in MTLCopyAllDevices()) if ([x.name containsString:@"Arc"]) d = x;
  if (!d) { printf("no Arc\n"); return 1; }
  printf("device %s supports32BitFloatFiltering %d\n", d.name.UTF8String, d.supports32BitFloatFiltering);
  NSError *e = nil; id<MTLLibrary> l = [d newLibraryWithSource:kSrc options:nil error:&e];
  id<MTLComputePipelineState> p = [d newComputePipelineStateWithFunction:[l newFunctionWithName:@"k"] error:&e];
  if (!p) { printf("FAIL pipeline %s\n", e.localizedDescription.UTF8String); return 2; }
  MTLSamplerDescriptor *sd = [MTLSamplerDescriptor new]; sd.minFilter = sd.magFilter = MTLSamplerMinMagFilterLinear;
  id<MTLSamplerState> s = [d newSamplerStateWithDescriptor:sd];
  MTLPixelFormat fm[3] = { MTLPixelFormatR32Float, MTLPixelFormatRG32Float, MTLPixelFormatRGBA32Float }; int comps[3] = { 1, 2, 4 }; int bad = 0;
  id<MTLCommandQueue> q = [d newCommandQueue];
  for (int f = 0; f < 3; f++) {
    MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:fm[f] width:2 height:1 mipmapped:NO];
    id<MTLTexture> t = [d newTextureWithDescriptor:td];
    float px[8] = { 0 }; for (int c = 0; c < comps[f]; c++) { px[c] = 0; px[comps[f] + c] = 1; }
    [t replaceRegion:MTLRegionMake2D(0, 0, 2, 1) mipmapLevel:0 withBytes:px bytesPerRow:comps[f] * 4 * 2];
    id<MTLBuffer> o = [d newBufferWithLength:3 * 16 options:MTLResourceStorageModeShared];
    id<MTLCommandBuffer> cb = [q commandBuffer]; id<MTLComputeCommandEncoder> en = [cb computeCommandEncoder];
    [en setComputePipelineState:p]; [en setTexture:t atIndex:0]; [en setSamplerState:s atIndex:0]; [en setBuffer:o offset:0 atIndex:0];
    [en dispatchThreads:MTLSizeMake(3, 1, 1) threadsPerThreadgroup:MTLSizeMake(3, 1, 1)]; [en endEncoding]; [cb commit]; [cb waitUntilCompleted];
    const float *r = o.contents; // u = 0.25 (texel 0 centre) -> 0, 0.5 -> 0.5, 0.75 (texel 1 centre) -> 1
    const BOOL ok = fabsf(r[0]) < 1e-4f && fabsf(r[4] - 0.5f) < 1e-3f && fabsf(r[8] - 1) < 1e-4f;
    printf("%s %s: %.4f %.4f %.4f (want 0 0.5 1)\n", ok ? "PASS" : "FAIL", f == 0 ? "R32Float" : f == 1 ? "RG32Float" : "RGBA32Float", r[0], r[4], r[8]);
    bad += !ok;
  }
  return bad ? 4 : 0;
} }
