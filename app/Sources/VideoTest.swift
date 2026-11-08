// SPDX-License-Identifier: MIT
// The video part of the GPU test. Decoding: five small clips in the app (H.264, HEVC 8- and 10-bit, AV1, VP9; 720p,
// 15 frames, made with ffmpeg from its testsrc2 pattern) go through VideoToolbox with a hardware decoder required, and
// each frame must equal ffmpeg's software decode bit for bit (the MD5 of its planes, *.md5 next to the clips; decoders
// of these codecs are exact by specification). Encoding: frames of a moving pattern are encoded in hardware at 1080p
// (H.264, HEVC, AV1 where there is an encoder), decoded again in hardware, and compared with the source (PSNR); and
// HEVC at 4K gives the decode rate. Nothing is written to disk.
import AVFoundation
import CoreMedia
import CoreVideo
import CryptoKit
import Foundation
import VideoToolbox

private let requireHW = [kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder as String: true] as CFDictionary

/// Frames of `samples` decoded by a hardware decoder, in presentation order (nil: no hardware decoder took it).
private func hwDecode(_ samples: [CMSampleBuffer], format: CMFormatDescription, pixelFormat: OSType) -> [CVPixelBuffer]? {
    var session: VTDecompressionSession?
    let attrs = [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat] as CFDictionary
    guard VTDecompressionSessionCreate(allocator: nil, formatDescription: format, decoderSpecification: requireHW,
                                       imageBufferAttributes: attrs, outputCallback: nil, decompressionSessionOut: &session) == noErr,
          let s = session else { return nil }
    defer { VTDecompressionSessionInvalidate(s) }
    let lock = NSLock(); var frames: [(CMTime, CVPixelBuffer)] = []
    for sb in samples {
        let st = VTDecompressionSessionDecodeFrame(s, sampleBuffer: sb, flags: [], infoFlagsOut: nil) { status, _, image, pts, _ in
            if status == noErr, let image { lock.lock(); frames.append((pts, image)); lock.unlock() }
        }
        if st != noErr { return nil }
    }
    VTDecompressionSessionWaitForAsynchronousFrames(s)
    return frames.sorted { CMTimeCompare($0.0, $1.0) < 0 }.map { $0.1 }
}

/// MD5 of a frame laid out as ffmpeg's yuv420p (8-bit) or yuv420p10le (10-bit): Y, then U, then V, rows without padding.
private func planarMD5(_ pb: CVPixelBuffer, tenBit: Bool) -> String {
    CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let w = CVPixelBufferGetWidthOfPlane(pb, 0), h = CVPixelBufferGetHeightOfPlane(pb, 0)
    let cw = CVPixelBufferGetWidthOfPlane(pb, 1), ch = CVPixelBufferGetHeightOfPlane(pb, 1)
    var md5 = Insecure.MD5()
    let y = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!, ys = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
    let uv = CVPixelBufferGetBaseAddressOfPlane(pb, 1)!, uvs = CVPixelBufferGetBytesPerRowOfPlane(pb, 1)
    if !tenBit {
        for r in 0..<h { md5.update(bufferPointer: UnsafeRawBufferPointer(start: y + r * ys, count: w)) }
        var u = [UInt8](repeating: 0, count: cw), v = [UInt8](repeating: 0, count: cw)
        var us: [UInt8] = [], vs: [UInt8] = []; us.reserveCapacity(cw * ch); vs.reserveCapacity(cw * ch)
        for r in 0..<ch {
            let row = (uv + r * uvs).assumingMemoryBound(to: UInt8.self)
            for i in 0..<cw { u[i] = row[2 * i]; v[i] = row[2 * i + 1] }
            us += u; vs += v
        }
        us.withUnsafeBytes { md5.update(bufferPointer: $0) }; vs.withUnsafeBytes { md5.update(bufferPointer: $0) }
    } else {   // P010: the 10 bits in the high bits of each 16-bit sample; yuv420p10le has them in the low bits
        var line = [UInt16](repeating: 0, count: w)
        for r in 0..<h {
            let row = (y + r * ys).assumingMemoryBound(to: UInt16.self)
            for i in 0..<w { line[i] = (row[i] >> 6).littleEndian }
            line.withUnsafeBytes { md5.update(bufferPointer: $0) }
        }
        var us: [UInt16] = [], vs: [UInt16] = []
        for r in 0..<ch {
            let row = (uv + r * uvs).assumingMemoryBound(to: UInt16.self)
            for i in 0..<cw { us.append((row[2 * i] >> 6).littleEndian); vs.append((row[2 * i + 1] >> 6).littleEndian) }
        }
        us.withUnsafeBytes { md5.update(bufferPointer: $0) }; vs.withUnsafeBytes { md5.update(bufferPointer: $0) }
    }
    return md5.finalize().map { String(format: "%02x", $0) }.joined()
}

/// The compressed samples and format of a clip's video track.
private func readClip(_ url: URL) -> ([CMSampleBuffer], CMFormatDescription)? {
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .video).first, let reader = try? AVAssetReader(asset: asset) else { return nil }
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    reader.add(out)
    guard reader.startReading() else { return nil }
    var samples: [CMSampleBuffer] = []
    while let sb = out.copyNextSampleBuffer() { if CMSampleBufferGetNumSamples(sb) > 0 { samples.append(sb) } }
    guard let fd = samples.first.flatMap({ CMSampleBufferGetFormatDescription($0) }) else { return nil }
    return (samples, fd)
}

private func decodeTests() -> [TestResult] {
    VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_VP9)
    var out: [TestResult] = []
    let clips: [(String, String, Bool)] = [("H.264", "h264", false), ("HEVC", "hevc", false), ("HEVC 10-bit", "hevc10", true), ("AV1", "av1", false), ("VP9", "vp9", false)]
    for (title, file, ten) in clips {
        let name = String(localized: "\(title) decode")
        guard let url = Bundle.main.url(forResource: file, withExtension: "mp4", subdirectory: "videotest"),
              let refText = try? String(contentsOf: url.deletingPathExtension().appendingPathExtension("md5"), encoding: .utf8) else {
            out.append(TestResult(title: name, value: String(localized: "Test clip missing"), state: .warning)); continue
        }
        let ref = refText.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let (samples, fd) = readClip(url) else { out.append(TestResult(title: name, value: String(localized: "Could not read the clip"), state: .warning)); continue }
        let t0 = CFAbsoluteTimeGetCurrent()
        guard let frames = hwDecode(samples, format: fd, pixelFormat: ten ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) else {
            out.append(TestResult(title: name, value: String(localized: "No hardware decoder"), state: .bad)); continue
        }
        let dt = CFAbsoluteTimeGetCurrent() - t0
        let got = frames.map { planarMD5($0, tenBit: ten) }
        let wrong = zip(got, ref).filter { $0 != $1 }.count + abs(got.count - ref.count)
        out.append(TestResult(title: name, value: wrong == 0 ? String(localized: "Exact (\(got.count) frames, \(Int(Double(got.count) / dt)) fps at 720p)")
                                                             : String(localized: "\(wrong) of \(ref.count) frames differ"),
                              state: wrong == 0 ? .good : .bad,
                              help: wrong == 0 ? "" : String(localized: "A hardware decoder must give exactly the reference decoder's pixels; different frames mean corrupted video.")))
    }
    return out
}

// MARK: - encode, decode back, compare

/// A moving pattern in an NV12 buffer: diagonal ramps, a sweeping bar and coloured blocks.
private func patternFrame(_ pool: CVPixelBufferPool, _ n: Int) -> CVPixelBuffer? {
    var pb: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pb)
    guard let pb else { return nil }
    CVPixelBufferLockBaseAddress(pb, []); defer { CVPixelBufferUnlockBaseAddress(pb, []) }
    let w = CVPixelBufferGetWidthOfPlane(pb, 0), h = CVPixelBufferGetHeightOfPlane(pb, 0)
    let y = CVPixelBufferGetBaseAddressOfPlane(pb, 0)!.assumingMemoryBound(to: UInt8.self), ys = CVPixelBufferGetBytesPerRowOfPlane(pb, 0)
    for r in 0..<h { let row = y + r * ys; let bar = abs(r - (n * 7) % h) < 24
        for c in 0..<w { row[c] = bar ? 235 : UInt8(truncatingIfNeeded: 16 + (c + r + n * 3) % 220) } }
    let uv = CVPixelBufferGetBaseAddressOfPlane(pb, 1)!.assumingMemoryBound(to: UInt8.self), uvs = CVPixelBufferGetBytesPerRowOfPlane(pb, 1)
    for r in 0..<(h / 2) { let row = uv + r * uvs
        for c in 0..<(w / 2) { let blk = ((c / 32) + (r / 32) + n / 4) % 4
            row[2 * c] = UInt8(64 + blk * 40); row[2 * c + 1] = UInt8(200 - blk * 30) } }
    return pb
}

private func psnrY(_ a: CVPixelBuffer, _ b: CVPixelBuffer) -> Double {
    CVPixelBufferLockBaseAddress(a, .readOnly); CVPixelBufferLockBaseAddress(b, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(a, .readOnly); CVPixelBufferUnlockBaseAddress(b, .readOnly) }
    let w = min(CVPixelBufferGetWidthOfPlane(a, 0), CVPixelBufferGetWidthOfPlane(b, 0)), h = min(CVPixelBufferGetHeightOfPlane(a, 0), CVPixelBufferGetHeightOfPlane(b, 0))
    let pa = CVPixelBufferGetBaseAddressOfPlane(a, 0)!.assumingMemoryBound(to: UInt8.self), sa = CVPixelBufferGetBytesPerRowOfPlane(a, 0)
    let pb = CVPixelBufferGetBaseAddressOfPlane(b, 0)!.assumingMemoryBound(to: UInt8.self), sb = CVPixelBufferGetBytesPerRowOfPlane(b, 0)
    var se = 0.0
    for r in stride(from: 0, to: h, by: 2) { for c in stride(from: 0, to: w, by: 2) { let d = Double(pa[r * sa + c]) - Double(pb[r * sb + c]); se += d * d } }
    let mse = se / Double((h / 2) * (w / 2))
    return mse <= 0 ? 99 : 10 * log10(255 * 255 / mse)
}

/// Hardware encode of `count` frames: (samples, format, frames per second), nil without a hardware encoder.
private func hwEncode(_ codec: CMVideoCodecType, w: Int, h: Int, count: Int, bitrate: Int, keep: inout [CVPixelBuffer]) -> ([CMSampleBuffer], CMFormatDescription, Double)? {
    let spec = [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder as String: true] as CFDictionary
    var session: VTCompressionSession?
    guard VTCompressionSessionCreate(allocator: nil, width: Int32(w), height: Int32(h), codecType: codec, encoderSpecification: spec,
                                     imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
                                     compressionSessionOut: &session) == noErr, let s = session else { return nil }
    defer { VTCompressionSessionInvalidate(s) }
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanFalse)
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
    VTSessionSetProperty(s, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
    var pool: CVPixelBufferPool?
    CVPixelBufferPoolCreate(nil, nil, [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                       kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
                                       kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &pool)
    guard let pool else { return nil }
    var src: [CVPixelBuffer] = []
    for i in 0..<count { if let f = patternFrame(pool, i) { src.append(f) } }
    let lock = NSLock(); var outs: [CMSampleBuffer] = []
    let t0 = CFAbsoluteTimeGetCurrent()
    for (i, f) in src.enumerated() {
        let st = VTCompressionSessionEncodeFrame(s, imageBuffer: f, presentationTimeStamp: CMTime(value: CMTimeValue(i), timescale: 30), duration: .invalid,
                                                 frameProperties: nil, infoFlagsOut: nil) { status, _, sb in
            if status == noErr, let sb { lock.lock(); outs.append(sb); lock.unlock() }
        }
        if st != noErr { return nil }
    }
    VTCompressionSessionCompleteFrames(s, untilPresentationTimeStamp: .invalid)
    let dt = CFAbsoluteTimeGetCurrent() - t0
    keep = src
    guard let fd = outs.first.flatMap({ CMSampleBufferGetFormatDescription($0) }) else { return nil }
    return (outs, fd, Double(outs.count) / dt)
}

private func encodeTests() -> [TestResult] {
    var out: [TestResult] = []
    for (title, codec) in [("H.264", kCMVideoCodecType_H264), ("HEVC", kCMVideoCodecType_HEVC), ("AV1", kCMVideoCodecType_AV1)] {
        let name = String(localized: "\(title) encode, 1080p")
        var src: [CVPixelBuffer] = []
        guard let (samples, fd, fps) = hwEncode(codec, w: 1920, h: 1080, count: 60, bitrate: 12_000_000, keep: &src) else {
            out.append(TestResult(title: name, value: String(localized: "No hardware encoder"), state: codec == kCMVideoCodecType_AV1 ? .info : .warning)); continue
        }
        var quality = String(localized: "not checked")
        var good = fps >= 60
        if let back = hwDecode(samples, format: fd, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), back.count == src.count {
            let ps = stride(from: 0, to: back.count, by: 10).map { psnrY(src[$0], back[$0]) }
            let mean = ps.reduce(0, +) / Double(ps.count)
            quality = String(format: "PSNR %.1f dB", mean); good = good && mean >= 30
        }
        out.append(TestResult(title: name, value: String(format: "%.0f fps, ", fps) + quality, state: good ? .good : .warning,
                              help: good ? "" : String(localized: "Encoding should run well above real time with a PSNR above 30 dB at this bitrate.")))
    }
    // 4K HEVC decode rate (the stream made by the hardware encoder)
    var src: [CVPixelBuffer] = []
    if let (samples, fd, _) = hwEncode(kCMVideoCodecType_HEVC, w: 3840, h: 2160, count: 60, bitrate: 40_000_000, keep: &src) {
        src = []
        let t0 = CFAbsoluteTimeGetCurrent()
        if let frames = hwDecode(samples, format: fd, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            let fps = Double(frames.count) / (CFAbsoluteTimeGetCurrent() - t0)
            out.append(TestResult(title: String(localized: "HEVC decode, 4K"), value: String(format: "%.0f fps", fps), state: fps >= 120 ? .good : fps >= 60 ? .warning : .bad,
                                  help: fps >= 60 ? "" : String(localized: "4K video needs at least 60 fps of decoding for smooth playback.")))
        }
    }
    return out
}

func runVideoTests(progress: (String) -> Void) -> [TestResult] {
    progress(String(localized: "Video decoding…"))
    var out = decodeTests()
    progress(String(localized: "Video encoding…"))
    out += encodeTests()
    return out
}
