// SPDX-License-Identifier: MIT
// mtl_props: the Metal device properties a plugin answers (registry, location and link rate, peers, feature queries,
// limits, sparse tiers) on the Arc device; on a staged plugin through nvmtl_interpose it compares two builds. A missing
// one is an unrecognized selector (the plugin before merge 1a6eba3 threw on supportsPlacementSparse).
#import <Metal/Metal.h>
int main(void) { @autoreleasepool {
    NSArray<id<MTLDevice>> *all = MTLCopyAllDevices(); id<MTLDevice> d = nil;
    for (id<MTLDevice> x in all) if ([x.name containsString:@"Arc"]) d = x;
    if (!d) { printf("no Arc device\n"); return 1; }
    printf("name %s | class %s\n", d.name.UTF8String, NSStringFromClass([d class]).UTF8String);
    printf("registryID 0x%llx location %ld locationNumber %lu maxTransferRate %llu\n", d.registryID, (long)d.location, (unsigned long)d.locationNumber, d.maxTransferRate);
    printf("peerGroupID %llu peerIndex %u peerCount %u lowPower %d headless %d removable %d unified %d\n", d.peerGroupID, d.peerIndex, d.peerCount, d.lowPower, d.headless, d.removable, d.hasUnifiedMemory);
    printf("32BitFloatFiltering %d 32BitMSAA %d QueryTextureLOD %d PullModel %d", d.supports32BitFloatFiltering, d.supports32BitMSAA, d.supportsQueryTextureLOD, d.supportsPullModelInterpolation);
    if (@available(macOS 26.4, *)) printf(" PlacementSparse %d", d.supportsPlacementSparse);
    printf("\n");
    printf("maxArgumentBufferSamplerCount %lu maxConcurrentCompilationTaskCount %lu sparseTileSize %lu recommendedMaxWorkingSet %llu\n", (unsigned long)d.maxArgumentBufferSamplerCount, (unsigned long)d.maximumConcurrentCompilationTaskCount, (unsigned long)d.sparseTileSizeInBytes, d.recommendedMaxWorkingSetSize);
    id<MTLBuffer> b = [d newBufferWithLength:4096 options:0];
    if (@available(macOS 26.0, *)) printf("buffer sparseBufferTier %ld\n", (long)b.sparseBufferTier);
    MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:16 height:16 mipmapped:NO];
    id<MTLTexture> t = [d newTextureWithDescriptor:td];
    if (@available(macOS 26.0, *)) printf("texture sparseTextureTier %ld\n", (long)t.sparseTextureTier);
    return 0;
} }
