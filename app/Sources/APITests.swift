// SPDX-License-Identifier: MIT
// The full GPU test's feature part: the Metal features apps and games lean on (texture formats, BC compression,
// mipmaps, MSAA, depth, blending, argument buffers on a heap, indirect command buffers, ray tracing), then OpenGL,
// OpenCL and the Vulkan loader. Each draws or computes something small whose right answer is known and checks it.
import AppKit
import Foundation
import Metal
import OpenCL
import OpenGL.GL3

private let apiShaders = """
#include <metal_stdlib>
using namespace metal;
kernel void fill_tex(texture2d<float, access::write> t [[texture(0)]], uint2 g [[thread_position_in_grid]]) { t.write(float4(0.25, 0.5, 0.75, 1.0), g); }
kernel void read_tex(texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]], device float4 *o [[buffer(0)]]) { o[0] = t.sample(s, float2(0.5, 0.5)); }
kernel void read_lod(texture2d<float> t [[texture(0)]], device float4 *o [[buffer(0)]]) { o[0] = t.read(uint2(0, 0), 4); }
struct Args { device const float *a; device float *b; };
kernel void via_args(constant Args &args [[buffer(0)]], uint i [[thread_position_in_grid]]) { args.b[i] = args.a[i] * 2.0f + 1.0f; }
kernel void icb_k(device float *o [[buffer(0)]], uint i [[thread_position_in_grid]]) { o[i] = float(i) * 3.0f; }
struct V { float4 p [[position]]; };
vertex V full(uint v [[vertex_id]], constant float &z [[buffer(0)]]) { const float2 p[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) }; V o; o.p = float4(p[v], z, 1); return o; }
fragment float4 flat(constant float4 &c [[buffer(0)]]) { return c; }
"""

private let rtShader = """
#include <metal_stdlib>
using namespace metal;
using namespace raytracing;
kernel void trace(primitive_acceleration_structure as [[buffer(0)]], device uint *o [[buffer(1)]], uint i [[thread_position_in_grid]]) {
    ray r; r.origin = float3(i == 0 ? 0.25 : 5.0, 0.25, -1); r.direction = float3(0, 0, 1); r.min_distance = 0; r.max_distance = 10;
    intersector<triangle_data> it; intersection_result<triangle_data> h = it.intersect(r, as);
    o[i] = h.type == intersection_type::triangle ? 1u : 0u;
}
"""

private func run(_ q: MTLCommandQueue, _ body: (MTLCommandBuffer) -> Void) -> Bool {
    guard let cb = q.makeCommandBuffer() else { return false }
    body(cb); cb.commit(); cb.waitUntilCompleted()
    return cb.status == .completed
}
private func near(_ a: SIMD4<Float>, _ b: SIMD4<Float>, _ eps: Float = 0.02) -> Bool { (0..<4).allSatisfy { Swift.abs(a[$0] - b[$0]) <= eps } }
private func pass(_ title: String, _ ok: Bool, _ detail: String = "") -> TestResult {
    TestResult(title: title, value: ok ? String(localized: "Correct") : (detail.isEmpty ? String(localized: "Wrong") : detail), state: ok ? .good : .bad)
}

func runAPITests(progress: (String) -> Void) -> [TestResult] {
    var out: [TestResult] = []
    guard let d = MTLCreateSystemDefaultDevice(), let q = d.makeCommandQueue() else { return out }
    guard let lib = try? d.makeLibrary(source: apiShaders, options: nil) else {
        return [TestResult(title: "Metal", value: String(localized: "Shader compiler failed"), state: .bad)]
    }
    func cps(_ n: String) -> MTLComputePipelineState? { lib.makeFunction(name: n).flatMap { try? d.makeComputePipelineState(function: $0) } }
    let readBuf = d.makeBuffer(length: 64, options: .storageModeShared)!
    func readBack() -> SIMD4<Float> { readBuf.contents().load(as: SIMD4<Float>.self) }
    let sampler: MTLSamplerState = { let sd = MTLSamplerDescriptor(); sd.minFilter = .linear; sd.magFilter = .linear; return d.makeSamplerState(descriptor: sd)! }()
    func sample(_ t: MTLTexture) -> SIMD4<Float>? {
        guard let p = cps("read_tex") else { return nil }
        guard run(q, { cb in let e = cb.makeComputeCommandEncoder()!; e.setComputePipelineState(p); e.setTexture(t, index: 0); e.setSamplerState(sampler, index: 0)
            e.setBuffer(readBuf, offset: 0, index: 0); e.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)); e.endEncoding() }) else { return nil }
        return readBack()
    }

    // texture formats written by a kernel and sampled back
    progress(String(localized: "Texture formats…"))
    var fmtBad: [String] = []
    for (name, f) in [("RGBA8", MTLPixelFormat.rgba8Unorm), ("RGBA16F", .rgba16Float), ("RGBA32F", .rgba32Float), ("BGRA8 sRGB", .bgra8Unorm_srgb)] {
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: f, width: 64, height: 64, mipmapped: false)
        td.usage = f == .bgra8Unorm_srgb ? [.shaderRead, .renderTarget] : [.shaderRead, .shaderWrite]; td.storageMode = .private
        guard let t = d.makeTexture(descriptor: td) else { fmtBad.append(name); continue }
        var ok = false
        if f == .bgra8Unorm_srgb {   // not writable from a kernel: cleared by a render pass instead
            let rp = MTLRenderPassDescriptor(); rp.colorAttachments[0].texture = t; rp.colorAttachments[0].loadAction = .clear
            rp.colorAttachments[0].clearColor = MTLClearColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1); rp.colorAttachments[0].storeAction = .store
            _ = run(q) { cb in cb.makeRenderCommandEncoder(descriptor: rp)!.endEncoding() }
        } else if let p = cps("fill_tex") {
            _ = run(q) { cb in let e = cb.makeComputeCommandEncoder()!; e.setComputePipelineState(p); e.setTexture(t, index: 0)
                e.dispatchThreads(MTLSize(width: 64, height: 64, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)); e.endEncoding() }
        }
        if let v = sample(t) { ok = near(v, SIMD4(0.25, 0.5, 0.75, 1)) }
        if !ok { fmtBad.append(name) }
    }
    out.append(pass(String(localized: "Texture formats (RGBA8, RGBA16F, RGBA32F, sRGB)"), fmtBad.isEmpty, String(localized: "Wrong: \(fmtBad.joined(separator: ", "))")))

    // BC1 (DXT1) compressed texture: one block, both endpoints red, every texel index 0
    if d.supportsBCTextureCompression {
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bc1_rgba, width: 4, height: 4, mipmapped: false)
        td.usage = .shaderRead
        if let t = d.makeTexture(descriptor: td) {
            let block: [UInt8] = [0x00, 0xF8, 0x00, 0xF8, 0, 0, 0, 0]
            t.replace(region: MTLRegionMake2D(0, 0, 4, 4), mipmapLevel: 0, withBytes: block, bytesPerRow: 8)
            out.append(pass(String(localized: "Compressed textures (BC1)"), sample(t).map { near($0, SIMD4(1, 0, 0, 1), 0.03) } ?? false))
        }
    }
    // mipmaps generated by the GPU
    do {
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 256, height: 256, mipmapped: true)
        td.usage = [.shaderRead, .shaderWrite]; td.storageMode = .private
        if let t = d.makeTexture(descriptor: td), let fill = cps("fill_tex"), let rl = cps("read_lod") {
            let ok = run(q) { cb in
                let e = cb.makeComputeCommandEncoder()!; e.setComputePipelineState(fill); e.setTexture(t, index: 0)
                e.dispatchThreads(MTLSize(width: 256, height: 256, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)); e.endEncoding()
                let b = cb.makeBlitCommandEncoder()!; b.generateMipmaps(for: t); b.endEncoding()
                let r = cb.makeComputeCommandEncoder()!; r.setComputePipelineState(rl); r.setTexture(t, index: 0); r.setBuffer(readBuf, offset: 0, index: 0)
                r.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)); r.endEncoding()
            }
            out.append(pass(String(localized: "Mipmap generation"), ok && near(readBack(), SIMD4(0.25, 0.5, 0.75, 1), 0.01)))
        }
    }

    // render: MSAA 4x with resolve, depth test, alpha blending
    progress(String(localized: "Rendering features…"))
    if let vf = lib.makeFunction(name: "full"), let ff = lib.makeFunction(name: "flat") {
        func pipe(_ samples: Int, depth: Bool, blend: Bool) -> MTLRenderPipelineState? {
            let rd = MTLRenderPipelineDescriptor(); rd.vertexFunction = vf; rd.fragmentFunction = ff; rd.rasterSampleCount = samples
            rd.colorAttachments[0].pixelFormat = .rgba8Unorm
            if depth { rd.depthAttachmentPixelFormat = .depth32Float }
            if blend { let c = rd.colorAttachments[0]!; c.isBlendingEnabled = true; c.sourceRGBBlendFactor = .sourceAlpha; c.destinationRGBBlendFactor = .oneMinusSourceAlpha
                c.sourceAlphaBlendFactor = .one; c.destinationAlphaBlendFactor = .zero }
            return try? d.makeRenderPipelineState(descriptor: rd)
        }
        func tex(_ f: MTLPixelFormat, samples: Int = 1, rt: Bool = true) -> MTLTexture {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: f, width: 64, height: 64, mipmapped: false)
            td.usage = [.renderTarget, .shaderRead]; td.storageMode = .private
            if samples > 1 { td.textureType = .type2DMultisample; td.sampleCount = samples }
            return d.makeTexture(descriptor: td)!
        }
        // MSAA
        if let p = pipe(4, depth: false, blend: false), d.supportsTextureSampleCount(4) {
            let ms = tex(.rgba8Unorm, samples: 4), res = tex(.rgba8Unorm)
            let rp = MTLRenderPassDescriptor(); rp.colorAttachments[0].texture = ms; rp.colorAttachments[0].resolveTexture = res
            rp.colorAttachments[0].loadAction = .clear; rp.colorAttachments[0].storeAction = .multisampleResolve
            var c = SIMD4<Float>(0, 1, 0, 1), z: Float = 0.5
            _ = run(q) { cb in let e = cb.makeRenderCommandEncoder(descriptor: rp)!; e.setRenderPipelineState(p); e.setVertexBytes(&z, length: 4, index: 0)
                e.setFragmentBytes(&c, length: 16, index: 0); e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3); e.endEncoding() }
            out.append(pass(String(localized: "Multisampling (MSAA 4x)"), sample(res).map { near($0, c) } ?? false))
        }
        // depth: red at z 0.3, then green at z 0.7 with depth "less": red stays
        if let p = pipe(1, depth: true, blend: false) {
            let col = tex(.rgba8Unorm), dep = tex(.depth32Float)
            let rp = MTLRenderPassDescriptor(); rp.colorAttachments[0].texture = col; rp.colorAttachments[0].loadAction = .clear; rp.colorAttachments[0].storeAction = .store
            rp.depthAttachment.texture = dep; rp.depthAttachment.loadAction = .clear; rp.depthAttachment.clearDepth = 1; rp.depthAttachment.storeAction = .dontCare
            let dd = MTLDepthStencilDescriptor(); dd.depthCompareFunction = .less; dd.isDepthWriteEnabled = true
            let ds = d.makeDepthStencilState(descriptor: dd)!
            var red = SIMD4<Float>(1, 0, 0, 1), green = SIMD4<Float>(0, 1, 0, 1), z1: Float = 0.3, z2: Float = 0.7
            _ = run(q) { cb in let e = cb.makeRenderCommandEncoder(descriptor: rp)!; e.setRenderPipelineState(p); e.setDepthStencilState(ds)
                e.setVertexBytes(&z1, length: 4, index: 0); e.setFragmentBytes(&red, length: 16, index: 0); e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                e.setVertexBytes(&z2, length: 4, index: 0); e.setFragmentBytes(&green, length: 16, index: 0); e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3); e.endEncoding() }
            out.append(pass(String(localized: "Depth test"), sample(col).map { near($0, red) } ?? false))
        }
        // blending: 50% grey over black
        if let p = pipe(1, depth: false, blend: true) {
            let col = tex(.rgba8Unorm)
            let rp = MTLRenderPassDescriptor(); rp.colorAttachments[0].texture = col; rp.colorAttachments[0].loadAction = .clear
            rp.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1); rp.colorAttachments[0].storeAction = .store
            var c = SIMD4<Float>(1, 1, 1, 0.5), z: Float = 0.5
            _ = run(q) { cb in let e = cb.makeRenderCommandEncoder(descriptor: rp)!; e.setRenderPipelineState(p); e.setVertexBytes(&z, length: 4, index: 0)
                e.setFragmentBytes(&c, length: 16, index: 0); e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3); e.endEncoding() }
            out.append(pass(String(localized: "Blending"), sample(col).map { near($0, SIMD4(0.5, 0.5, 0.5, 0.5), 0.03) } ?? false))
        }
    }

    // argument buffer holding two buffers from a heap
    progress(String(localized: "Argument buffers…"))
    if let p = cps("via_args") {
        let hd = MTLHeapDescriptor(); hd.size = 1 << 20; hd.storageMode = .shared
        if let heap = d.makeHeap(descriptor: hd), let a = heap.makeBuffer(length: 4096, options: .storageModeShared), let b = heap.makeBuffer(length: 4096, options: .storageModeShared) {
            let pa = a.contents().bindMemory(to: Float.self, capacity: 1024); for i in 0..<1024 { pa[i] = Float(i) }
            let args = d.makeBuffer(length: 16, options: .storageModeShared)!
            args.contents().storeBytes(of: a.gpuAddress, toByteOffset: 0, as: UInt64.self); args.contents().storeBytes(of: b.gpuAddress, toByteOffset: 8, as: UInt64.self)
            let ok = run(q) { cb in let e = cb.makeComputeCommandEncoder()!; e.setComputePipelineState(p); e.setBuffer(args, offset: 0, index: 0); e.useHeap(heap)
                e.dispatchThreads(MTLSize(width: 1024, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1)); e.endEncoding() }
            let pb = b.contents().bindMemory(to: Float.self, capacity: 1024)
            out.append(pass(String(localized: "Argument buffers and heaps"), ok && (0..<1024).allSatisfy { pb[$0] == Float($0) * 2 + 1 }))
        }
    }
    // indirect command buffer (compute)
    if let f = lib.makeFunction(name: "icb_k") {
        let pd = MTLComputePipelineDescriptor(); pd.computeFunction = f; pd.supportIndirectCommandBuffers = true
        let icbd = MTLIndirectCommandBufferDescriptor(); icbd.commandTypes = .concurrentDispatchThreads; icbd.inheritBuffers = false; icbd.inheritPipelineState = false; icbd.maxKernelBufferBindCount = 1
        if let p = try? d.makeComputePipelineState(descriptor: pd, options: [], reflection: nil), let icb = d.makeIndirectCommandBuffer(descriptor: icbd, maxCommandCount: 1, options: []) {
            let o = d.makeBuffer(length: 4096, options: .storageModeShared)!
            let cmd = icb.indirectComputeCommandAt(0); cmd.setComputePipelineState(p); cmd.setKernelBuffer(o, offset: 0, at: 0)
            cmd.concurrentDispatchThreads(MTLSize(width: 1024, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1))
            let ok = run(q) { cb in let e = cb.makeComputeCommandEncoder()!; e.useResource(o, usage: .write); e.executeCommandsInBuffer(icb, range: 0..<1); e.endEncoding() }
            let po = o.contents().bindMemory(to: Float.self, capacity: 1024)
            out.append(pass(String(localized: "Indirect command buffers"), ok && (0..<1024).allSatisfy { po[$0] == Float($0) * 3 }))
        }
    }
    // ray tracing: one triangle; ray 0 hits it, ray 1 misses
    progress(String(localized: "Ray tracing…"))
    if d.supportsRaytracing, let rl = try? d.makeLibrary(source: rtShader, options: nil), let f = rl.makeFunction(name: "trace"),
       let p = try? d.makeComputePipelineState(function: f) {
        let verts: [SIMD3<Float>] = [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        let vb = d.makeBuffer(bytes: verts, length: MemoryLayout<SIMD3<Float>>.stride * 3, options: .storageModeShared)!
        let g = MTLAccelerationStructureTriangleGeometryDescriptor(); g.vertexBuffer = vb; g.vertexStride = MemoryLayout<SIMD3<Float>>.stride; g.triangleCount = 1
        let ad = MTLPrimitiveAccelerationStructureDescriptor(); ad.geometryDescriptors = [g]
        let sizes = d.accelerationStructureSizes(descriptor: ad)
        if let accel = d.makeAccelerationStructure(size: sizes.accelerationStructureSize), let scratch = d.makeBuffer(length: max(sizes.buildScratchBufferSize, 16), options: .storageModePrivate) {
            let o = d.makeBuffer(length: 8, options: .storageModeShared)!
            let ok = run(q) { cb in
                let a = cb.makeAccelerationStructureCommandEncoder()!; a.build(accelerationStructure: accel, descriptor: ad, scratchBuffer: scratch, scratchBufferOffset: 0); a.endEncoding()
                let e = cb.makeComputeCommandEncoder()!; e.setComputePipelineState(p); e.setAccelerationStructure(accel, bufferIndex: 0); e.setBuffer(o, offset: 0, index: 1)
                e.dispatchThreads(MTLSize(width: 2, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 2, height: 1, depth: 1)); e.endEncoding()
            }
            let r = o.contents().bindMemory(to: UInt32.self, capacity: 2)
            out.append(pass(String(localized: "Ray tracing"), ok && r[0] == 1 && r[1] == 0))
        }
    } else if !d.supportsRaytracing {
        out.append(TestResult(title: String(localized: "Ray tracing"), value: String(localized: "Not offered by this device"), state: .warning))
    }

    progress(String(localized: "OpenGL…"))
    out.append(openGLTest())
    progress(String(localized: "OpenCL…"))
    out.append(openCLTest())
    out.append(vulkanCheck())
    return out
}

// MARK: - OpenGL: a hardware-accelerated context clears and draws into a framebuffer object, read back

private func openGLTest() -> TestResult {
    let attrs: [NSOpenGLPixelFormatAttribute] = [UInt32(NSOpenGLPFAAccelerated), UInt32(NSOpenGLPFANoRecovery), UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core), 0]
    guard let pf = NSOpenGLPixelFormat(attributes: attrs), let ctx = NSOpenGLContext(format: pf, share: nil) else {
        return TestResult(title: "OpenGL", value: String(localized: "No accelerated context"), state: .bad)
    }
    ctx.makeCurrentContext(); defer { NSOpenGLContext.clearCurrentContext() }
    let renderer = glGetString(GLenum(GL_RENDERER)).map { String(cString: $0) } ?? "?"
    var fbo: GLuint = 0, rb: GLuint = 0
    glGenFramebuffers(1, &fbo); glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo)
    glGenRenderbuffers(1, &rb); glBindRenderbuffer(GLenum(GL_RENDERBUFFER), rb)
    glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_RGBA8), 16, 16)
    glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), rb)
    glViewport(0, 0, 16, 16); glClearColor(0.25, 0.5, 0.75, 1); glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    var px = [UInt8](repeating: 0, count: 4)
    glReadPixels(8, 8, 1, 1, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &px)
    glDeleteRenderbuffers(1, &rb); glDeleteFramebuffers(1, &fbo)
    let ok = abs(Int(px[0]) - 64) <= 2 && abs(Int(px[1]) - 128) <= 2 && abs(Int(px[2]) - 191) <= 2
    return TestResult(title: "OpenGL", value: (ok ? String(localized: "Correct") : String(localized: "Wrong")) + "  (\(renderer))", state: ok ? .good : .bad)
}

// MARK: - OpenCL: a kernel adds two arrays on the GPU device

private func openCLTest() -> TestResult {
    var platform: cl_platform_id?
    guard clGetPlatformIDs(1, &platform, nil) == CL_SUCCESS else { return TestResult(title: "OpenCL", value: String(localized: "No platform"), state: .bad) }
    var dev: cl_device_id?
    guard clGetDeviceIDs(platform, cl_device_type(CL_DEVICE_TYPE_GPU), 1, &dev, nil) == CL_SUCCESS, let dev else {
        return TestResult(title: "OpenCL", value: String(localized: "No GPU device"), state: .bad)
    }
    var name = [CChar](repeating: 0, count: 256); clGetDeviceInfo(dev, cl_device_info(CL_DEVICE_NAME), 256, &name, nil)
    var err: cl_int = 0
    var devs: cl_device_id? = dev
    guard let ctx = clCreateContext(nil, 1, &devs, nil, nil, &err), let q = clCreateCommandQueue(ctx, dev, 0, &err) else {
        return TestResult(title: "OpenCL", value: String(localized: "No context"), state: .bad)
    }
    defer { clReleaseCommandQueue(q); clReleaseContext(ctx) }
    let src = "__kernel void add(__global const float *a, __global const float *b, __global float *c) { int i = get_global_id(0); c[i] = a[i] + b[i]; }"
    var ok = false
    src.withCString { s in
        var sp: UnsafePointer<CChar>? = s
        guard let prog = clCreateProgramWithSource(ctx, 1, &sp, nil, &err), clBuildProgram(prog, 1, &devs, nil, nil, nil) == CL_SUCCESS,
              let k = clCreateKernel(prog, "add", &err) else { return }
        let n = 1024
        var a = (0..<n).map { Float($0) }, b = (0..<n).map { Float($0 % 5) }, c = [Float](repeating: -1, count: n)
        let ba = clCreateBuffer(ctx, cl_mem_flags(CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR), n * 4, &a, &err)
        let bb = clCreateBuffer(ctx, cl_mem_flags(CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR), n * 4, &b, &err)
        let bc = clCreateBuffer(ctx, cl_mem_flags(CL_MEM_WRITE_ONLY), n * 4, nil, &err)
        var ma = ba, mb = bb, mc = bc
        clSetKernelArg(k, 0, MemoryLayout<cl_mem>.size, &ma); clSetKernelArg(k, 1, MemoryLayout<cl_mem>.size, &mb); clSetKernelArg(k, 2, MemoryLayout<cl_mem>.size, &mc)
        var gs = n
        if clEnqueueNDRangeKernel(q, k, 1, nil, &gs, nil, 0, nil, nil) == CL_SUCCESS,
           clEnqueueReadBuffer(q, bc, cl_bool(CL_TRUE), 0, n * 4, &c, 0, nil, nil) == CL_SUCCESS {
            ok = (0..<n).allSatisfy { c[$0] == a[$0] + b[$0] }
        }
        clReleaseMemObject(ba); clReleaseMemObject(bb); clReleaseMemObject(bc); clReleaseKernel(k); clReleaseProgram(prog)
    }
    return TestResult(title: "OpenCL", value: (ok ? String(localized: "Correct") : String(localized: "Wrong")) + "  (\(String(cString: name)))", state: ok ? .good : .bad)
}

// MARK: - Vulkan: the loader and the driver's manifest (games and Zink use them)

private func vulkanCheck() -> TestResult {
    let fm = FileManager.default
    let loader = ["/usr/local/lib/libvulkan.1.dylib", "/Library/IntelXe/GL/libvulkan.1.dylib"].first { fm.fileExists(atPath: $0) }
    let icd = ["/usr/local/share/vulkan/icd.d/intel_icd.x86_64.json", "/Library/GPUBundles/nvmtl/intel_icd.json"].first { fm.fileExists(atPath: $0) }
    switch (loader, icd) {
    case (.some, .some): return TestResult(title: "Vulkan", value: String(localized: "Loader and Intel driver installed"), state: .good)
    case (nil, .some): return TestResult(title: "Vulkan", value: String(localized: "Intel driver installed, no Vulkan loader (install the Zink GL package for one)"), state: .info)
    default: return TestResult(title: "Vulkan", value: String(localized: "Not installed"), state: .info)
    }
}
