// SPDX-License-Identifier: MIT
// The Monitor page: what the card does right now, once a second, with the last minute drawn. Read only and cheap:
// sysctls anyone may read (NMXAccel's presented frames, IntelXe's VRAM use and, from 0.1.4, debug.intelxe.sensors with
// the GT clock and temperatures) and the main display's mode from CoreGraphics.
import CoreGraphics
import Foundation
import SwiftUI

func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buf = [CChar](repeating: 0, count: size + 1)
    guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
    return String(cString: buf)
}
func sysctlInt(_ name: String) -> Int64? {
    var v: Int64 = 0, size = MemoryLayout<Int64>.size
    if sysctlbyname(name, &v, &size, nil, 0) == 0 { return size == 4 ? Int64(Int32(truncatingIfNeeded: v)) : v }
    var v32: Int32 = 0; size = 4
    return sysctlbyname(name, &v32, &size, nil, 0) == 0 ? Int64(v32) : nil
}
private func firstInt(_ text: String, after label: String) -> Int? {
    guard let r = text.range(of: label) else { return nil }
    let digits = text[r.upperBound...].drop(while: { $0 == " " }).prefix(while: { $0.isNumber })
    return Int(digits)
}

struct MonitorSample {
    var fps: Double?
    var actMHz: Int?, reqMHz: Int?, maxMHz: Int?
    var packageC: Int?, vramC: Int?
    var vramUsedMB: Int?
    var mode = ""
}

final class MonitorModel: ObservableObject {
    @Published var now = MonitorSample()
    @Published var fpsHistory: [Double] = []
    @Published var clockHistory: [Double] = []
    @Published var sensorsMissing = false
    private var timer: Timer?
    private var lastFrames: Int64?
    private var lastTime = Date()

    func start() {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.sample() }
    }
    func stop() { timer?.invalidate(); timer = nil; lastFrames = nil }

    private func sample() {
        var s = MonitorSample()
        let t = Date()
        if let frames = sysctlInt("debug.nmxaccel_async_frames") {
            if let last = lastFrames { s.fps = Double(frames - last) / max(0.1, t.timeIntervalSince(lastTime)) }
            lastFrames = frames
        }
        lastTime = t
        if let text = sysctlString("debug.intelxe.sensors"), text.hasPrefix("act") {
            s.actMHz = firstInt(text, after: "act"); s.reqMHz = firstInt(text, after: "req"); s.maxMHz = firstInt(text, after: "RP0")
            s.packageC = firstInt(text, after: "package"); s.vramC = firstInt(text, after: "VRAM")
            sensorsMissing = false
        } else { sensorsMissing = sysctlString("debug.intelxe.state") != nil }
        if let v = sysctlString("debug.intelxe.vram"), let a = firstInt(v, after: "): used"), let b = firstInt(v, after: "the window: used") { s.vramUsedMB = a + b }
        let id = CGMainDisplayID()
        if let m = CGDisplayCopyDisplayMode(id) {
            let hz = m.refreshRate
            s.mode = "\(m.width)x\(m.height)" + (m.pixelWidth != m.width ? " (\(m.pixelWidth)x\(m.pixelHeight) " + String(localized: "pixels") + ")" : "")
                + (hz > 0 ? String(format: ", %.0f Hz", hz) : "")
        }
        now = s
        if let f = s.fps { fpsHistory.append(f); if fpsHistory.count > 60 { fpsHistory.removeFirst() } }
        if let c = s.actMHz { clockHistory.append(Double(c)); if clockHistory.count > 60 { clockHistory.removeFirst() } }
    }
}

struct Sparkline: View {
    let values: [Double]
    let top: Double
    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1, top > 0 else { return }
            var p = Path()
            for (i, v) in values.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(max(59, values.count - 1))
                let y = size.height * (1 - CGFloat(min(v, top) / top))
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(p, with: .color(.accentColor), lineWidth: 1.5)
        }
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08)))
    }
}

struct MonitorView: View {
    @EnvironmentObject var manager: Manager
    @StateObject var model = MonitorModel()
    @AppStorage("menuBarItem") var menuBarItem = false
    var body: some View {
        let s = model.now
        Form {
            Section2(title: "Display", symbol: "display") {
                LabeledContent("Mode") { Text(s.mode.isEmpty ? "–" : s.mode) }
                LabeledContent("Variable refresh") { Text(manager.vrrActive ? String(localized: "Offered") : String(localized: "Off")) }
                LabeledContent("Frames presented") { Text(s.fps.map { String(format: "%.0f / s", $0) } ?? "–") }
                Sparkline(values: model.fpsHistory, top: max(60, model.fpsHistory.max() ?? 60))
                Text("Frames the display took in the last second: it rises with motion on screen and falls to a few when nothing moves.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section2(title: "GPU", symbol: "gauge.medium") {
                if model.sensorsMissing {
                    Label("The GPU clock and temperatures need IntelXe.kext 0.1.4 or later in your EFI.", systemImage: "info.circle").foregroundStyle(.secondary)
                } else {
                    LabeledContent("Clock") {
                        Text(s.actMHz.map { $0 == 0 ? String(localized: "idle (power saving)") : "\($0) MHz" } ?? "–")
                            + Text(s.maxMHz.map { "   (" + String(localized: "max") + " \($0) MHz)" } ?? "").foregroundColor(.secondary)
                    }
                    Sparkline(values: model.clockHistory, top: Double(s.maxMHz ?? 2850))
                    LabeledContent("Temperature") {
                        Text([s.packageC.map { String(localized: "GPU \($0) °C") }, s.vramC.map { String(localized: "memory \($0) °C") }].compactMap { $0 }.joined(separator: ", ").ifEmpty("–"))
                    }
                }
                LabeledContent("Video memory in use") { Text(s.vramUsedMB.map { String(format: "%.1f GB", Double($0) / 1024) } ?? "–") }
            }
            Section2(title: "Menu bar", symbol: "menubar.rectangle") {
                CaptionedToggle(title: "Show in the menu bar", caption: "Frames, GPU clock and temperature, and the display sizes (HiDPI ones too) to switch with one click.", isOn: $menuBarItem)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

extension String { func ifEmpty(_ other: String) -> String { isEmpty ? other : self } }
