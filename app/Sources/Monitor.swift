// SPDX-License-Identifier: MIT
// The Monitor page: what the card does right now, once a second, with the last five minutes drawn. Read only and cheap:
// sysctls anyone may read (NMXAccel's presented frames, IntelXe's VRAM use and, from 0.1.4, debug.intelxe.sensors with
// the GT clock and temperatures) and the main display's mode from CoreGraphics.
import Charts
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

/// The GT clock's hardware range as IntelXe reads it (debug.intelxe.sensors, from 0.1.4): RP0, the most the GPU runs at,
/// and RPn, the least. nil without the sysctl or while the GPU sleeps.
func gtClockLimits() -> (rp0: Int, rpn: Int)? {
    guard let text = sysctlString("debug.intelxe.sensors"), text.hasPrefix("act"),
          let rp0 = firstInt(text, after: "RP0"), let rpn = firstInt(text, after: "RPn"), rp0 > 0 else { return nil }
    return (rp0, rpn)
}

/// The GT clock range of the default setting: IntelXe's SLPC floor of 1200 MHz (Wa_14022085890) up to RP0, both kept
/// within RPn...RP0 as the kernel keeps them (xe_core.cpp slpcParams). The B580: 1200-2850 MHz.
func defaultClockRange(rp0: Int, rpn: Int) -> (min: Int, max: Int) { (min(max(1200, rpn), rp0), rp0) }

struct MonitorSample {
    var fps: Double?
    var actMHz: Int?, reqMHz: Int?, maxMHz: Int?
    var packageC: Int?, vramC: Int?
    var vramUsedMB: Int?
    var mode = ""
}

/// One reading for the Monitor page's charts.
struct MonitorPoint: Identifiable {
    let t: Date
    let v: Double
    var id: Date { t }
}

final class MonitorModel: ObservableObject {
    @Published var now = MonitorSample()
    /// the last five minutes, one point a second
    @Published var fpsHistory: [MonitorPoint] = []
    @Published var clockHistory: [MonitorPoint] = []
    @Published var tempHistory: [MonitorPoint] = []
    @Published var sensorsMissing = false
    /// the last RP0 read: the clock chart's top while the GPU sleeps
    var lastMaxMHz: Int?
    static let window: TimeInterval = 300
    /// false: keep the values set from outside (the snapshots)
    var live = true
    private var timer: Timer?
    private var lastFrames: Int64?
    private var lastTime = Date()

    func start() {
        guard live, timer == nil else { return }
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
            if let m = s.maxMHz, m > 0 { lastMaxMHz = m }
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
        let oldest = t.addingTimeInterval(-Self.window)
        func add(_ value: Double?, to list: inout [MonitorPoint]) {
            if let value { list.append(MonitorPoint(t: t, v: value)) }
            if let i = list.firstIndex(where: { $0.t >= oldest }), i > 0 { list.removeFirst(i) }
        }
        add(s.fps, to: &fpsHistory)
        add(s.actMHz.map(Double.init), to: &clockHistory)
        add(s.packageC.map(Double.init), to: &tempHistory)
    }
}

/// The last five minutes of one reading: a line over a light wash, its scale on the right.
struct MetricChart: View {
    let points: [MonitorPoint]
    let color: Color
    let top: Double
    var body: some View {
        let end = points.last?.t ?? Date()
        Chart(points) { p in
            AreaMark(x: .value("Time", p.t), y: .value("Value", min(p.v, top)))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", p.t), y: .value("Value", min(p.v, top)))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.6))
                .interpolationMethod(.monotone)
        }
        .chartXScale(domain: end.addingTimeInterval(-MonitorModel.window)...end)
        .chartYScale(domain: 0...top)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel().font(.caption2)
            }
        }
        .overlay {
            if points.count < 2 { Text("No readings yet").font(.caption).foregroundStyle(.secondary) }
        }
        .frame(width: 230, height: 58)
        .accessibilityLabel(Text("The last five minutes"))
    }
}

/// A reading as a number with a line under it, and its chart beside it.
struct MetricRow: View {
    let title: LocalizedStringKey
    let symbol: String
    let value: String
    var detail: String = ""
    let points: [MonitorPoint]
    let color: Color
    let top: Double
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(.secondary)
                Text(value).font(.title3.weight(.semibold).monospacedDigit()).contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: value)
                if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            MetricChart(points: points, color: color, top: top)
        }
        .padding(.vertical, 2)
    }
}

struct MonitorView: View {
    @EnvironmentObject var manager: Manager
    @StateObject var model: MonitorModel
    @AppStorage("menuBarItem") var menuBarItem = false
    init(model: MonitorModel = MonitorModel()) { _model = StateObject(wrappedValue: model) }
    var body: some View {
        let s = model.now
        Form {
            Section2(title: "GPU", symbol: "gauge.medium") {
                if model.sensorsMissing {
                    Label("The GPU clock and temperatures need IntelXe.kext 0.1.4 or later in your EFI.", systemImage: "info.circle").foregroundStyle(.secondary)
                } else {
                    MetricRow(title: "Clock", symbol: "speedometer",
                              value: s.actMHz.map { $0 == 0 ? String(localized: "idle (power saving)") : "\($0) MHz" } ?? "–",
                              detail: s.maxMHz.map { String(localized: "max") + " \($0) MHz" } ?? "",
                              points: model.clockHistory, color: .accentColor,
                              top: Double(s.maxMHz ?? model.lastMaxMHz ?? max(1000, Int(model.clockHistory.map(\.v).max() ?? 0))))
                    MetricRow(title: "Temperature", symbol: "thermometer.medium",
                              value: s.packageC.map { String(localized: "GPU \($0) °C") } ?? "–",
                              detail: s.vramC.map { String(localized: "memory \($0) °C") } ?? "",
                              points: model.tempHistory, color: .orange, top: max(100, model.tempHistory.map(\.v).max() ?? 0))
                }
                LabeledContent("Video memory in use") { Text(s.vramUsedMB.map { String(format: "%.1f GB", Double($0) / 1024) } ?? "–") }
            }
            Section2(title: "Display", symbol: "display") {
                MetricRow(title: "Frames presented", symbol: "film.stack",
                          value: s.fps.map { String(format: "%.0f ", $0) + String(localized: "frames/s") } ?? "–",
                          detail: String(localized: "Rises with motion on screen, a few when nothing moves."),
                          points: model.fpsHistory, color: .green, top: max(60, model.fpsHistory.map(\.v).max() ?? 60))
                LabeledContent("Mode") { Text(s.mode.isEmpty ? "–" : s.mode) }
                LabeledContent("Variable refresh") { Text(manager.vrrActive ? String(localized: "Offered") : String(localized: "Off")) }
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
