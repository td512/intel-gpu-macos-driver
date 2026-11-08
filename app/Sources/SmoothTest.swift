// SPDX-License-Identifier: MIT
// The smoothness test: a window on the main display draws a moving bar at the display's full rate for five seconds,
// and each frame's on-screen time (MTLDrawable presentedTime) is recorded. From the gaps: the rate reached, frames
// that came a refresh or more late (a visible stutter), and how even the pacing was.
import AppKit
import Metal
import QuartzCore

private final class SmoothRunner: NSObject {
    let window: NSWindow
    let layer = CAMetalLayer()
    let device: MTLDevice
    let queue: MTLCommandQueue
    var presented: [CFTimeInterval] = []
    var link: CVDisplayLink?
    var frame = 0
    let lock = NSLock()

    init?(device: MTLDevice) {
        guard let q = device.makeCommandQueue(), let screen = NSScreen.main else { return nil }
        self.device = device; queue = q
        let size = NSSize(width: 640, height: 360)
        window = NSWindow(contentRect: NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.midY - size.height / 2, width: size.width, height: size.height),
                          styleMask: [.titled], backing: .buffered, defer: false, screen: screen)
        super.init()
        window.title = String(localized: "Smoothness test")
        let view = NSView(frame: NSRect(origin: .zero, size: size)); view.wantsLayer = true
        layer.device = device; layer.pixelFormat = .bgra8Unorm; layer.framebufferOnly = true
        layer.drawableSize = CGSize(width: size.width * screen.backingScaleFactor, height: size.height * screen.backingScaleFactor)
        layer.displaySyncEnabled = true; layer.maximumDrawableCount = 3
        view.layer = layer; window.contentView = view
    }

    func snapshot() -> [CFTimeInterval] { lock.lock(); defer { lock.unlock() }; return presented.sorted() }

    /// One frame: clear to a colour whose bar position moves, present, note when it reached the screen.
    func draw() {
        guard let d = layer.nextDrawable(), let cb = queue.makeCommandBuffer() else { return }
        let rp = MTLRenderPassDescriptor(); rp.colorAttachments[0].texture = d.texture; rp.colorAttachments[0].loadAction = .clear
        let t = Double(frame % 120) / 120; frame += 1
        rp.colorAttachments[0].clearColor = MTLClearColor(red: t, green: 0.3, blue: 1 - t, alpha: 1); rp.colorAttachments[0].storeAction = .store
        cb.makeRenderCommandEncoder(descriptor: rp)?.endEncoding()
        d.addPresentedHandler { [weak self] dr in
            guard let self, dr.presentedTime > 0 else { return }
            self.lock.lock(); self.presented.append(dr.presentedTime); self.lock.unlock()
        }
        cb.present(d); cb.commit()
    }
}

/// Runs on the main thread for about six seconds (the window must be on screen); returns the results.
@MainActor func runSmoothTest() async -> [TestResult] {
    guard let d = MTLCreateSystemDefaultDevice(), let r = SmoothRunner(device: d) else { return [] }
    r.window.makeKeyAndOrderFront(nil)
    let hz = Double(NSScreen.main?.maximumFramesPerSecond ?? 60)
    let end = Date().addingTimeInterval(5.5)
    try? await Task.sleep(nanoseconds: 400_000_000)   // let the window settle
    while Date() < end {
        r.draw()
        try? await Task.sleep(nanoseconds: UInt64(1e9 / hz / 2))   // twice per refresh: the drawable queue paces it
    }
    try? await Task.sleep(nanoseconds: 300_000_000)
    r.window.orderOut(nil)
    let times = r.snapshot()
    guard times.count > 30 else {
        return [TestResult(title: String(localized: "Smoothness"), value: String(localized: "Too few frames reached the screen (\(times.count))"), state: .bad)]
    }
    let gaps = zip(times.dropFirst(), times).map { $0 - $1 }
    let span = times.last! - times.first!, fps = Double(gaps.count) / span
    let period = 1 / hz
    let late = gaps.filter { $0 > period * 1.5 }.count
    let mean = gaps.reduce(0, +) / Double(gaps.count)
    let sd = (gaps.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(gaps.count)).squareRoot()
    let okRate = fps >= hz * 0.95, okLate = Double(late) <= Double(gaps.count) * 0.01
    return [
        TestResult(title: String(localized: "Frame rate in a window"), value: String(format: "%.0f fps (", fps) + String(localized: "display") + String(format: " %.0f Hz)", hz),
                   state: okRate ? .good : fps >= hz * 0.75 ? .warning : .bad,
                   help: okRate ? "" : String(localized: "The display's full rate was not reached: in a scaled (HiDPI) size the compositor does more work; in the monitor's own size this points at the driver.")),
        TestResult(title: String(localized: "Late frames"), value: String(localized: "\(late) of \(gaps.count)") + String(format: ", ± %.2f ms", sd * 1000),
                   state: okLate ? .good : .warning,
                   help: okLate ? "" : String(localized: "Frames shown a refresh or more late are visible as stutter."))
    ]
}
