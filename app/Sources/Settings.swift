// SPDX-License-Identifier: MIT
// The Settings page: the driver's settings that IntelXe and IntelXeFB read from NVRAM at start (written through the
// password dialog; the display ones are applied at once too, through their sysctls), and the app's own.
import Foundation
import ServiceManagement
import SwiftUI

/// NVRAM value of a key, nil when unset (or "ok", which the kexts read as unset).
func nvramValue(_ key: String) -> String? {
    guard let out = commandOutput("/usr/sbin/nvram", [key]), let tab = out.firstIndex(of: "\t") else { return nil }
    let v = out[out.index(after: tab)...].trimmingCharacters(in: .whitespacesAndNewlines)
    return v.isEmpty || v == "ok" ? nil : v
}

struct DriverSettings: Equatable {
    var profile = 0          // intelxe-gpu-profile: 0 balanced, 1 power saving
    var clocks = 0           // 0 default, 1 quiet (max 1800 MHz), 2 performance (min 2400 MHz)
    var hwCursor = true      // intelxefb-hwcursor
    var dpms = false         // intelxefb-dpms
    var lfc = true           // intelxefb-vrr-lfc
    var vrrFloor = 0         // intelxefb-vrr-floor (Hz, 0 = the panel's)
    var gpuTiming = false    // /tmp/nvmtl-gputime (test builds of the Metal driver)

    static func read() -> DriverSettings {
        var s = DriverSettings()
        s.profile = Int(nvramValue("intelxe-gpu-profile") ?? "") ?? 0
        let mn = Int(nvramValue("intelxe-gpu-min-mhz") ?? "") ?? 0, mx = Int(nvramValue("intelxe-gpu-max-mhz") ?? "") ?? 0
        s.clocks = mx > 0 && mx <= 1800 ? 1 : mn >= 2400 ? 2 : 0
        s.hwCursor = (nvramValue("intelxefb-hwcursor") ?? "1") != "0"
        s.dpms = (nvramValue("intelxefb-dpms") ?? "0") == "1"
        s.lfc = (nvramValue("intelxefb-vrr-lfc") ?? "1") != "0"
        s.vrrFloor = Int(nvramValue("intelxefb-vrr-floor") ?? "") ?? 0
        s.gpuTiming = FileManager.default.fileExists(atPath: "/tmp/nvmtl-gputime")
        return s
    }

    /// The shell commands that make `self` so (NVRAM for the next start; the display sysctls at once).
    func commands() -> String {
        let (mn, mx) = clocks == 1 ? (0, 1800) : clocks == 2 ? (2400, 0) : (0, 0)
        var c = [
            "/usr/sbin/nvram intelxe-gpu-profile=\(profile)",
            "/usr/sbin/nvram intelxe-gpu-min-mhz=\(mn)", "/usr/sbin/nvram intelxe-gpu-max-mhz=\(mx)",
            "/usr/sbin/nvram intelxefb-hwcursor=\(hwCursor ? 1 : 0)", "/usr/sbin/nvram intelxefb-dpms=\(dpms ? 1 : 0)",
            "/usr/sbin/nvram intelxefb-vrr-lfc=\(lfc ? 1 : 0)", "/usr/sbin/nvram intelxefb-vrr-floor=\(vrrFloor)",
            "/usr/sbin/sysctl -q debug.intelxefb_hwcursor=\(hwCursor ? 1 : 0) debug.intelxefb_dpms=\(dpms ? 1 : 0) debug.intelxefb_vrr_lfc=\(lfc ? 1 : 0) debug.intelxefb_vrr_floor_hz=\(vrrFloor) || true",
        ]
        c.append(gpuTiming ? "/usr/bin/touch /tmp/nvmtl-gputime && /bin/chmod 644 /tmp/nvmtl-gputime" : "/bin/rm -f /tmp/nvmtl-gputime")
        return c.joined(separator: " && ")
    }
}

extension Manager {
    func applySettings(_ s: DriverSettings) {
        perform(title: String(localized: "Save the driver settings"), command: s.commands(), needsRoot: true, then: { result in
            if result.cancelled { self.lastResult = String(localized: "Cancelled. Nothing changed.") }
            else if result.succeeded { self.lastResult = String(localized: "Saved. The display settings apply now; the power settings at the next start."); self.rebootNeeded = true }
            else { self.lastResult = String(localized: "It did not finish. See the log.") }
        })
    }
}

// Plain observable state (no SwiftUI macros: the app builds with the command line tools alone)
final class SettingsState: ObservableObject {
    @Published var saved = DriverSettings()
    @Published var edit = DriverSettings()
    @Published var loaded = false
    @Published var loginItem = SMAppService.mainApp.status == .enabled
}

struct SettingsView: View {
    @EnvironmentObject var manager: Manager
    @StateObject var st = SettingsState()
    @AppStorage("autoUpdateCheck") var autoUpdateCheck = true

    var body: some View {
        Form {
            Section2(title: "Power") {
                Picker("GPU power profile", selection: $st.edit.profile) {
                    Text("Balanced").tag(0); Text("Power saving").tag(1)
                }
                Picker("GPU clock", selection: $st.edit.clocks) {
                    Text("Default (1200–2850 MHz)").tag(0)
                    Text("Quiet (up to 1800 MHz: less heat and fan noise)").tag(1)
                    Text("Performance (at least 2400 MHz: lowest latency, more power)").tag(2)
                }
                Text("Applied at the next start.").font(.caption).foregroundStyle(.secondary)
            }
            Section2(title: "Diagnostics") {
                CaptionedToggle(title: "GPU timing in the driver's log", caption: "For performance reports; test builds of the Metal driver only.", isOn: $st.edit.gpuTiming)
                HStack {
                    Text("Power and diagnostics are saved together; the power settings apply at the next start.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Revert") { st.edit = st.saved }.disabled(st.edit == st.saved)
                    Button("Save") { manager.applySettings(st.edit); st.saved = st.edit }.disabled(st.edit == st.saved).keyboardShortcut(.defaultAction)
                }
            }
            Section2(title: "This app") {
                CaptionedToggle(title: "Open at login", caption: "Keeps the menu bar item there. Applies at once.", isOn: Binding(get: { st.loginItem }, set: { on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                    st.loginItem = SMAppService.mainApp.status == .enabled
                }))
                CaptionedToggle(title: "Check for a new release at start", caption: "Asks GitHub for the latest release when the app opens.", isOn: $autoUpdateCheck)
            }
        }
        .formStyle(.grouped)
        .task {
            if !st.loaded { let s = await Task.detached { DriverSettings.read() }.value; st.saved = s; st.edit = s; st.loaded = true }
        }
    }
}

/// The display settings (Display page): the same NVRAM keys and sysctls as the Power and app page's, saved together.
struct DisplayTroubleshootingView: View {
    @EnvironmentObject var manager: Manager
    @StateObject var st = SettingsState()
    var body: some View {
        Section2(title: "Display troubleshooting") {
                CaptionedToggle(title: "Hardware cursor", caption: "Turn off if the pointer flickers, leaves trails or has the wrong colours.", isOn: $st.edit.hwCursor)
                CaptionedToggle(title: "Output off when the display sleeps", caption: "Some monitors then wake more reliably, some less.", isOn: $st.edit.dpms)
                CaptionedToggle(title: "Low framerate compensation", caption: "In Variable refresh: repeats frames below the monitor's lowest rate.", isOn: $st.edit.lfc)
                Picker("Variable refresh lowest rate", selection: $st.edit.vrrFloor) {
                    Text("The monitor's own").tag(0); Text("48 Hz").tag(48); Text("60 Hz").tag(60)
                }
                Text("Raise the lowest rate if the monitor flickers in Variable refresh at low frame rates.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text("Applied at once and kept for the next starts.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Revert") { st.edit = st.saved }.disabled(st.edit == st.saved)
                    Button("Save") { manager.applySettings(st.edit); st.saved = st.edit }.disabled(st.edit == st.saved)
                }
            }
        .task {
            if !st.loaded { let s = await Task.detached { DriverSettings.read() }.value; st.saved = s; st.edit = s; st.loaded = true }
        }
    }
}

/// A switch with a short label and, under it, what it does.
struct CaptionedToggle: View {
    let title: LocalizedStringKey
    let caption: LocalizedStringKey
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(caption).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
