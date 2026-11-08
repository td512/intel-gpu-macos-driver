// SPDX-License-Identifier: MIT
// The long GPU test (about two minutes). Video memory: most of it in 512 MB buffers is filled by the GPU with a pattern
// made from each word's address, checked by the GPU, then filled with the inverse and checked again (a bad memory cell,
// a wrong mapping or a write that lands elsewhere shows as mismatches). Stability: a minute of full compute load while
// the GT clock and temperatures are sampled (debug.intelxe.sensors), watching for failed command buffers (a GPU reset)
// and for the clock falling under load (thermal or power throttling).
import Foundation
import Metal

private let memShaders = """
#include <metal_stdlib>
using namespace metal;
static inline uint pat(uint i, uint seed) { uint x = i * 2654435761u ^ seed; x ^= x >> 13; x *= 0x5bd1e995u; return x ^ (x >> 15); }
kernel void fillp(device uint *b [[buffer(0)]], constant uint &seed [[buffer(1)]], uint i [[thread_position_in_grid]]) { b[i] = pat(i, seed); }
kernel void checkp(device const uint *b [[buffer(0)]], constant uint &seed [[buffer(1)]], device atomic_uint *bad [[buffer(2)]],
                   uint i [[thread_position_in_grid]], uint lane [[thread_index_in_simdgroup]]) {
    const uint m = b[i] != pat(i, seed) ? 1u : 0u; const uint s = simd_sum(m);
    if (lane == 0 && s) atomic_fetch_add_explicit(bad, s, memory_order_relaxed);
}
kernel void burn(device float *o [[buffer(0)]], uint g [[thread_position_in_grid]]) {
    float a = g, b = g + 1, c = g + 2, d = g + 3;
    for (int i = 0; i < 4096; i++) { a = fma(a, 0.9999f, 0.001f); b = fma(b, 0.9999f, 0.001f); c = fma(c, 0.9999f, 0.001f); d = fma(d, 0.9999f, 0.001f); }
    o[g] = a + b + c + d;
}
"""

func runLongTest(progress: @escaping (String) -> Void) -> [TestResult] {
    var out: [TestResult] = []
    guard let d = MTLCreateSystemDefaultDevice(), let q = d.makeCommandQueue(), let lib = try? d.makeLibrary(source: memShaders, options: nil) else {
        return [TestResult(title: "Metal", value: String(localized: "No Metal device"), state: .bad)]
    }
    func cps(_ n: String) -> MTLComputePipelineState? { lib.makeFunction(name: n).flatMap { try? d.makeComputePipelineState(function: $0) } }
    guard let fill = cps("fillp"), let check = cps("checkp"), let burn = cps("burn") else { return out }

    // 1. video memory
    let chunk = 512 << 20, words = chunk / 4
    // XE_LONGTEST_GB / XE_LONGTEST_SECONDS: a shorter run (for checking the test itself)
    let env = ProcessInfo.processInfo.environment
    let budget = env["XE_LONGTEST_GB"].flatMap(Int.init).map { $0 << 30 } ?? min(Int(Double(d.recommendedMaxWorkingSetSize) * 0.8), 10 << 30)
    let seconds = env["XE_LONGTEST_SECONDS"].flatMap(Double.init) ?? 60
    var bufs: [MTLBuffer] = []
    while bufs.count * chunk + chunk <= budget, let b = d.makeBuffer(length: chunk, options: .storageModePrivate) { bufs.append(b) }
    let bad = d.makeBuffer(length: 4, options: .storageModeShared)!
    bad.contents().storeBytes(of: UInt32(0), as: UInt32.self)
    var failed = false
    let seeds: [UInt32] = [0x1234_5678, ~UInt32(0x1234_5678)]
    for (pass, seed) in seeds.enumerated() {
        progress(String(localized: "Video memory, pass \(pass + 1) of 2…"))
        for (k, b) in bufs.enumerated() {
            var s = seed &+ UInt32(k)
            guard let cb = q.makeCommandBuffer(), let e = cb.makeComputeCommandEncoder() else { failed = true; break }
            e.setComputePipelineState(fill); e.setBuffer(b, offset: 0, index: 0); e.setBytes(&s, length: 4, index: 1)
            e.dispatchThreads(MTLSize(width: words, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)); e.endEncoding()
            cb.commit(); cb.waitUntilCompleted(); if cb.status != .completed { failed = true }
        }
        for (k, b) in bufs.enumerated() {
            var s = seed &+ UInt32(k)
            guard let cb = q.makeCommandBuffer(), let e = cb.makeComputeCommandEncoder() else { failed = true; break }
            e.setComputePipelineState(check); e.setBuffer(b, offset: 0, index: 0); e.setBytes(&s, length: 4, index: 1); e.setBuffer(bad, offset: 0, index: 2)
            e.dispatchThreads(MTLSize(width: words, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)); e.endEncoding()
            cb.commit(); cb.waitUntilCompleted(); if cb.status != .completed { failed = true }
        }
    }
    let errors = bad.contents().load(as: UInt32.self)
    let gb = Double(bufs.count * chunk) / Double(1 << 30)
    out.append(TestResult(title: String(localized: "Video memory"),
                          value: failed ? String(localized: "The GPU stopped during the test") : errors == 0 ? String(format: String(localized: "%.1f GB tested twice, no errors"), gb)
                                 : String(format: String(localized: "%.1f GB tested, %u words wrong"), gb, errors),
                          state: failed || errors > 0 ? .bad : .good,
                          help: failed || errors > 0 ? String(localized: "Wrong words in video memory point at the card (memory, overclock, heat) or at how the driver maps it; a report helps tell them apart.") : ""))
    bufs = []

    // 2. a minute of full load
    let o = d.makeBuffer(length: 160 * 1024 * 16 * 4, options: .storageModePrivate)!
    var clocks: [Int] = [], temps: [Int] = [], errorsLoad = 0
    let t0 = Date(); var lastSample = Date.distantPast
    while Date().timeIntervalSince(t0) < seconds {
        if Date().timeIntervalSince(lastSample) >= 1 {
            lastSample = Date()
            progress(String(localized: "Load, \(Int(Date().timeIntervalSince(t0))) of \(Int(seconds)) s…"))
            if let s = sysctlString("debug.intelxe.sensors"), s.hasPrefix("act") {
                let parts = s.split(separator: " ")
                if let i = parts.firstIndex(of: "act"), i + 1 < parts.count, let v = Int(parts[i + 1]) { clocks.append(v) }
                if let i = parts.firstIndex(of: "package"), i + 1 < parts.count, let v = Int(parts[i + 1]) { temps.append(v) }
            }
        }
        guard let cb = q.makeCommandBuffer(), let e = cb.makeComputeCommandEncoder() else { errorsLoad += 1; break }
        e.setComputePipelineState(burn); e.setBuffer(o, offset: 0, index: 0)
        e.dispatchThreads(MTLSize(width: 160 * 1024 * 16, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)); e.endEncoding()
        cb.commit(); cb.waitUntilCompleted()
        if cb.status != .completed { errorsLoad += 1 }
    }
    out.append(TestResult(title: String(localized: "A minute of full load"), value: errorsLoad == 0 ? String(localized: "No GPU errors") : String(localized: "\(errorsLoad) failed GPU jobs"),
                          state: errorsLoad == 0 ? .good : .bad,
                          help: errorsLoad == 0 ? "" : String(localized: "Jobs failing under load mean GPU resets or hangs: make a diagnostics report right after this.")))
    if clocks.count >= 10 {
        let busy = clocks.filter { $0 > 0 }
        let first = busy.prefix(busy.count / 2), second = busy.suffix(busy.count / 2)
        let a = first.isEmpty ? 0 : first.reduce(0, +) / first.count, b = second.isEmpty ? 0 : second.reduce(0, +) / second.count
        let drop = a > 0 ? Double(a - b) / Double(a) : 0
        out.append(TestResult(title: String(localized: "GPU clock under load"), value: "\(a) → \(b) MHz", state: drop > 0.15 ? .warning : .good,
                              help: drop > 0.15 ? String(localized: "The clock fell during the minute: the card gets too hot or reaches its power limit (airflow, fan curve, power cable).") : ""))
    }
    if let hot = temps.max() {
        out.append(TestResult(title: String(localized: "Highest GPU temperature"), value: "\(hot) °C", state: hot >= 90 ? .bad : hot >= 82 ? .warning : .good,
                              help: hot >= 82 ? String(localized: "Above about 85 °C the card lowers its clock; check the airflow in the case.") : ""))
    } else {
        out.append(TestResult(title: String(localized: "Clock and temperature"), value: String(localized: "Not read (needs IntelXe.kext 0.1.4 or later)"), state: .info))
    }
    return out
}
