// SPDX-License-Identifier: MIT
// A quick check of the GPU through Metal (about 15 s): does it compute and draw correctly, and are its compute rate,
// memory bandwidth, upload rate and round-trip latency where this card should be? A number far below says which part
// to look at (a low compute rate: the GPU or CPU clock; low uploads: the PCIe link or Resizable BAR). Then which video
// codecs macOS sees in hardware, with a short hardware-encode rate. Read only: nothing is installed or changed.
import CoreMedia
import CoreVideo
import Foundation
import Metal
import VideoToolbox

struct TestResult: Identifiable, Hashable {
    enum State { case good, warning, bad, info }
    let id = UUID()
    let title: String
    let value: String
    let state: State
    var help: String = ""
}

private let kernels = """
#include <metal_stdlib>
using namespace metal;
kernel void vadd(device const float *a [[buffer(0)]], device const float *b [[buffer(1)]], device float *c [[buffer(2)]], uint i [[thread_position_in_grid]]) { c[i] = a[i] + b[i]; }
kernel void fma16(device float *o [[buffer(0)]], constant float &a [[buffer(1)]], uint g [[thread_position_in_grid]]) {
    float x0 = g, x1 = g + 1, x2 = g + 2, x3 = g + 3, x4 = g + 4, x5 = g + 5, x6 = g + 6, x7 = g + 7;
    float y0 = -x0, y1 = -x1, y2 = -x2, y3 = -x3, y4 = -x4, y5 = -x5, y6 = -x6, y7 = -x7;
    for (int i = 0; i < 256; i++) {
        x0 = fma(x0, a, 0.001f); x1 = fma(x1, a, 0.001f); x2 = fma(x2, a, 0.001f); x3 = fma(x3, a, 0.001f);
        x4 = fma(x4, a, 0.001f); x5 = fma(x5, a, 0.001f); x6 = fma(x6, a, 0.001f); x7 = fma(x7, a, 0.001f);
        y0 = fma(y0, a, 0.001f); y1 = fma(y1, a, 0.001f); y2 = fma(y2, a, 0.001f); y3 = fma(y3, a, 0.001f);
        y4 = fma(y4, a, 0.001f); y5 = fma(y5, a, 0.001f); y6 = fma(y6, a, 0.001f); y7 = fma(y7, a, 0.001f); }
    o[g] = x0 + x1 + x2 + x3 + x4 + x5 + x6 + x7 + y0 + y1 + y2 + y3 + y4 + y5 + y6 + y7; }
kernel void copy4(device const float4 *a [[buffer(0)]], device float4 *b [[buffer(1)]], uint i [[thread_position_in_grid]]) { b[i] = a[i]; }
kernel void tiny(device uint *o [[buffer(0)]], uint i [[thread_position_in_grid]]) { if (i == 0) o[0] += 1; }
struct VOut { float4 p [[position]]; float4 c; };
vertex VOut tri(uint v [[vertex_id]]) { const float2 p[3] = { float2(-1, -1), float2(3, -1), float2(-1, 3) }; VOut o; o.p = float4(p[v], 0, 1); o.c = float4(0.25, 0.5, 0.75, 1); return o; }
fragment float4 col(VOut i [[stage_in]]) { return i.c; }
"""

/// GPU time of `body`'s command buffers, the best of `runs` after one warm-up.
private func gpuTime(_ q: MTLCommandQueue, runs: Int = 4, _ body: (MTLCommandBuffer) -> Void) -> Double {
    var best = Double.infinity
    for i in 0...runs {
        guard let cb = q.makeCommandBuffer() else { return .nan }
        body(cb); cb.commit(); cb.waitUntilCompleted()
        if i > 0, cb.status == .completed { best = min(best, cb.gpuEndTime - cb.gpuStartTime) }
    }
    return best
}

func runGPUTest(progress: @escaping (String) -> Void) -> [TestResult] {
    var out: [TestResult] = []
    guard let d = MTLCreateSystemDefaultDevice(), let q = d.makeCommandQueue() else {
        return [TestResult(title: String(localized: "Metal"), value: String(localized: "No Metal device"), state: .bad,
                           help: String(localized: "macOS runs without graphics acceleration. The System page and a diagnostics report say why."))]
    }
    out.append(TestResult(title: String(localized: "Metal device"), value: d.name, state: .info))
    // the expected rates are an Arc B580's; on another GPU the numbers are shown without a verdict
    let b580 = d.name.contains("B580") || d.name.contains("Arc")
    func judged(_ r: TestResult) -> TestResult { b580 ? r : TestResult(title: r.title, value: r.value, state: .info) }
    let lib: MTLLibrary
    do { lib = try d.makeLibrary(source: kernels, options: nil) } catch {
        return out + [TestResult(title: String(localized: "Shader compiler"), value: String(localized: "Failed"), state: .bad, help: error.localizedDescription)]
    }
    func pso(_ n: String) -> MTLComputePipelineState? { lib.makeFunction(name: n).flatMap { try? d.makeComputePipelineState(function: $0) } }

    // 1. compute is correct
    progress(String(localized: "Compute…"))
    if let p = pso("vadd") {
        let n = 1 << 20
        let a = d.makeBuffer(length: n * 4, options: .storageModeShared)!, b = d.makeBuffer(length: n * 4, options: .storageModeShared)!
        let c = d.makeBuffer(length: n * 4, options: .storageModeShared)!
        let pa = a.contents().bindMemory(to: Float.self, capacity: n), pb = b.contents().bindMemory(to: Float.self, capacity: n)
        for i in 0..<n { pa[i] = Float(i); pb[i] = Float(i % 7) * 0.5 }
        let cb = q.makeCommandBuffer()!, e = cb.makeComputeCommandEncoder()!
        e.setComputePipelineState(p); e.setBuffer(a, offset: 0, index: 0); e.setBuffer(b, offset: 0, index: 1); e.setBuffer(c, offset: 0, index: 2)
        e.dispatchThreads(MTLSize(width: n, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)); e.endEncoding()
        cb.commit(); cb.waitUntilCompleted()
        let pc = c.contents().bindMemory(to: Float.self, capacity: n)
        var bad = 0; for i in 0..<n where pc[i] != pa[i] + pb[i] { bad += 1 }
        out.append(TestResult(title: String(localized: "Compute results"), value: bad == 0 ? String(localized: "Correct") : String(localized: "\(bad) of \(n) wrong"),
                              state: bad == 0 ? .good : .bad))
    }
    // 2. drawing is correct
    progress(String(localized: "Drawing…"))
    if let vf = lib.makeFunction(name: "tri"), let ff = lib.makeFunction(name: "col") {
        let rd = MTLRenderPipelineDescriptor(); rd.vertexFunction = vf; rd.fragmentFunction = ff; rd.colorAttachments[0].pixelFormat = .rgba8Unorm
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 256, height: 256, mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]; td.storageMode = .managed
        if let rp = try? d.makeRenderPipelineState(descriptor: rd), let tex = d.makeTexture(descriptor: td) {
            let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = tex; pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store; pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            let cb = q.makeCommandBuffer()!, e = cb.makeRenderCommandEncoder(descriptor: pass)!
            e.setRenderPipelineState(rp); e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3); e.endEncoding()
            let bl = cb.makeBlitCommandEncoder()!; bl.synchronize(resource: tex); bl.endEncoding()
            cb.commit(); cb.waitUntilCompleted()
            var px = [UInt8](repeating: 0, count: 256 * 256 * 4)
            tex.getBytes(&px, bytesPerRow: 256 * 4, from: MTLRegionMake2D(0, 0, 256, 256), mipmapLevel: 0)
            var bad = 0
            for i in stride(from: 0, to: px.count, by: 4) where abs(Int(px[i]) - 64) > 2 || abs(Int(px[i + 1]) - 128) > 2 || abs(Int(px[i + 2]) - 191) > 2 || px[i + 3] != 255 { bad += 1 }
            out.append(TestResult(title: String(localized: "Drawing results"), value: bad == 0 ? String(localized: "Correct") : String(localized: "\(bad) of 65536 pixels wrong"),
                                  state: bad == 0 ? .good : .bad))
        }
    }
    // 3. compute rate (16 independent FMA chains per thread)
    progress(String(localized: "Compute rate…"))
    if let p = pso("fma16") {
        let n = 160 * 1024 * 16
        let o = d.makeBuffer(length: n * 4, options: .storageModePrivate)!
        var a: Float = 0.999
        let t = gpuTime(q) { cb in
            let e = cb.makeComputeCommandEncoder()!; e.setComputePipelineState(p); e.setBuffer(o, offset: 0, index: 0); e.setBytes(&a, length: 4, index: 1)
            e.dispatchThreads(MTLSize(width: n, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)); e.endEncoding()
        }
        let tf = Double(n) * 16 * 256 * 2 / t / 1e12
        out.append(judged(TestResult(title: String(localized: "Compute rate (FP32)"), value: String(format: "%.1f TFLOP/s", tf), state: tf >= 8 ? .good : tf >= 4 ? .warning : .bad,
                              help: tf >= 8 ? "" : String(localized: "An Arc B580 reaches about 13 TFLOP/s. Far less: the GPU clock is held low (power settings) or the CPU starves it (HybridPM)."))))
    }
    // 4. memory bandwidth (VRAM to VRAM)
    progress(String(localized: "Memory bandwidth…"))
    if let p = pso("copy4") {
        let bytes = 256 << 20
        let a = d.makeBuffer(length: bytes, options: .storageModePrivate)!, b = d.makeBuffer(length: bytes, options: .storageModePrivate)!
        let t = gpuTime(q) { cb in
            let e = cb.makeComputeCommandEncoder()!; e.setComputePipelineState(p); e.setBuffer(a, offset: 0, index: 0); e.setBuffer(b, offset: 0, index: 1)
            e.dispatchThreads(MTLSize(width: bytes / 16, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)); e.endEncoding()
        }
        let gbs = 2 * Double(bytes) / t / 1e9
        out.append(judged(TestResult(title: String(localized: "Memory bandwidth"), value: String(format: "%.0f GB/s", gbs), state: gbs >= 250 ? .good : gbs >= 120 ? .warning : .bad,
                              help: gbs >= 250 ? "" : String(localized: "An Arc B580's memory gives about 400 GB/s. Far less: the memory or GPU clock is held low."))))
    }
    // 5. upload (system memory to VRAM over PCIe)
    progress(String(localized: "Upload rate…"))
    do {
        let bytes = 256 << 20
        let s = d.makeBuffer(length: bytes, options: .storageModeShared)!, v = d.makeBuffer(length: bytes, options: .storageModePrivate)!
        let t = gpuTime(q) { cb in let bl = cb.makeBlitCommandEncoder()!; bl.copy(from: s, sourceOffset: 0, to: v, destinationOffset: 0, size: bytes); bl.endEncoding() }
        let gbs = Double(bytes) / t / 1e9
        out.append(judged(TestResult(title: String(localized: "Upload (PCIe)"), value: String(format: "%.1f GB/s", gbs), state: gbs >= 8 ? .good : gbs >= 3 ? .warning : .bad,
                              help: gbs >= 8 ? "" : String(localized: "The card's PCIe 4.0 x8 link moves about 12-14 GB/s. Far less: the link trained slower (slot, riser, BIOS PCIe setting)."))))
    }
    // 6. round trip: one tiny command buffer, committed and waited for
    progress(String(localized: "Latency…"))
    if let p = pso("tiny") {
        let o = d.makeBuffer(length: 64, options: .storageModePrivate)!
        var ts: [Double] = []
        for _ in 0..<64 {
            let t0 = CFAbsoluteTimeGetCurrent()
            let cb = q.makeCommandBuffer()!, e = cb.makeComputeCommandEncoder()!
            e.setComputePipelineState(p); e.setBuffer(o, offset: 0, index: 0)
            e.dispatchThreads(MTLSize(width: 64, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 64, height: 1, depth: 1)); e.endEncoding()
            cb.commit(); cb.waitUntilCompleted()
            ts.append((CFAbsoluteTimeGetCurrent() - t0) * 1e6)
        }
        let med = ts.sorted()[ts.count / 2]
        out.append(judged(TestResult(title: String(localized: "Round trip"), value: String(format: "%.0f µs", med), state: med <= 200 ? .good : med <= 600 ? .warning : .bad,
                              help: med <= 200 ? "" : String(localized: "One small job, sent and waited for, takes about 60 µs on the test machine. Much more: the GPU idles at a low clock between jobs."))))
    }
    progress(String(localized: "Video…"))
    out.append(contentsOf: videoCheck().map(judged))
    return out
}

// MARK: - video

private func videoCheck() -> [TestResult] {
    var out: [TestResult] = []
    let codecs: [(String, CMVideoCodecType)] = [("H.264", kCMVideoCodecType_H264), ("HEVC", kCMVideoCodecType_HEVC),
                                                ("AV1", kCMVideoCodecType_AV1), ("VP9", kCMVideoCodecType_VP9)]
    var decode: [String] = []
    for (name, c) in codecs where VTIsHardwareDecodeSupported(c) { decode.append(name) }
    out.append(TestResult(title: String(localized: "Hardware video decode"), value: decode.isEmpty ? String(localized: "None") : decode.joined(separator: ", "),
                          state: decode.count >= 3 ? .good : decode.isEmpty ? .bad : .warning,
                          help: decode.count >= 3 ? "" : String(localized: "The driver decodes H.264, HEVC, AV1 and VP9 on the card. Missing ones: the VideoToolbox components are not installed or did not load.")))
    var encoders: [String] = []
    var list: CFArray?
    if VTCopyVideoEncoderList(nil, &list) == noErr, let items = list as? [[String: Any]] {
        for item in items where (item[kVTVideoEncoderList_IsHardwareAccelerated as String] as? Bool) == true {
            // the main codecs only (Apple Silicon lists ProRes, depth and alpha variants too)
            if let n = item[kVTVideoEncoderList_DisplayName as String] as? String, n.range(of: #"H\.?264|HEVC|AV1|VP9"#, options: .regularExpression) != nil,
               !n.contains("Depth"), !n.contains("Disparity"), !n.contains("Alpha"), !encoders.contains(n) { encoders.append(n) }
        }
    }
    out.append(TestResult(title: String(localized: "Hardware video encoders"), value: encoders.isEmpty ? String(localized: "None") : encoders.joined(separator: ", "),
                          state: encoders.isEmpty ? .warning : .good))
    if let fps = encodeRate(kCMVideoCodecType_HEVC) {
        out.append(TestResult(title: String(localized: "HEVC encode, 1080p"), value: String(format: "%.0f fps", fps), state: fps >= 120 ? .good : fps >= 30 ? .warning : .bad))
    }
    return out
}

/// Frames per second encoding 1080p frames in hardware for about two seconds (nil without a hardware encoder).
private func encodeRate(_ codec: CMVideoCodecType) -> Double? {
    let w = 1920, h = 1080
    let spec = [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder as String: true] as CFDictionary
    var session: VTCompressionSession?
    guard VTCompressionSessionCreate(allocator: nil, width: Int32(w), height: Int32(h), codecType: codec, encoderSpecification: spec,
                                     imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
                                     compressionSessionOut: &session) == noErr, let s = session else { return nil }
    defer { VTCompressionSessionInvalidate(s) }
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanFalse)
    var pool: CVPixelBufferPool?
    let attrs = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelBufferWidthKey as String: w,
                 kCVPixelBufferHeightKey as String: h, kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary
    CVPixelBufferPoolCreate(nil, nil, attrs, &pool)
    guard let pool else { return nil }
    let lock = NSLock(); var done = 0
    let t0 = CFAbsoluteTimeGetCurrent(); var sent = 0
    while CFAbsoluteTimeGetCurrent() - t0 < 2.0 && sent < 2000 {
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
        guard let pb else { break }
        CVPixelBufferLockBaseAddress(pb, [])
        if let y = CVPixelBufferGetBaseAddressOfPlane(pb, 0) { memset(y, Int32(sent & 255), CVPixelBufferGetBytesPerRowOfPlane(pb, 0) * h) }
        CVPixelBufferUnlockBaseAddress(pb, [])
        let st = VTCompressionSessionEncodeFrame(s, imageBuffer: pb, presentationTimeStamp: CMTime(value: CMTimeValue(sent), timescale: 60),
                                                 duration: .invalid, frameProperties: nil, infoFlagsOut: nil) { _, _, _ in lock.lock(); done += 1; lock.unlock() }
        if st != noErr { return nil }
        sent += 1
    }
    VTCompressionSessionCompleteFrames(s, untilPresentationTimeStamp: .invalid)
    let t = CFAbsoluteTimeGetCurrent() - t0
    lock.lock(); let n = done; lock.unlock()
    return n > 0 ? Double(n) / t : nil
}
