// SPDX-License-Identifier: MIT
// The check at login: a LaunchAgent in the user's own ~/Library/LaunchAgents starts this app with --login-check once per
// login. It looks for what the start-up warnings look for (healthIssues: a system-volume copy that a macOS update
// removed, the boot guard holding acceleration off, a kext at another version, a recent panic...) and, only when there
// is something, shows one dialog; then it quits. Nothing runs as root and nothing is changed: fixing is the app's job,
// which the dialog opens. Off unless turned on (Power and app page, or the Driver page's Safari section).
import AppKit
import Foundation

let loginCheckLabel = "io.github.yusufklncc.IntelXeManager.login-check"
var loginCheckAgent: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(loginCheckLabel).plist")
}

func loginCheckEnabled() -> Bool { FileManager.default.fileExists(atPath: loginCheckAgent.path) }

/// Writes or removes the agent. It takes effect at the next login (nothing is started now).
func setLoginCheck(_ on: Bool) {
    if !on { try? FileManager.default.removeItem(at: loginCheckAgent); return }
    guard let binary = Bundle.main.executablePath else { return }
    let plist: [String: Any] = [
        "Label": loginCheckLabel,
        "ProgramArguments": [binary, "--login-check"],
        "RunAtLoad": true,
        "LimitLoadToSessionType": "Aqua",
        "ProcessType": "Interactive",
    ]
    try? FileManager.default.createDirectory(at: loginCheckAgent.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) { try? data.write(to: loginCheckAgent) }
}

/// The app was moved or updated in another place: point the agent at this copy.
func refreshLoginCheckPath() {
    guard loginCheckEnabled(), let binary = Bundle.main.executablePath,
          let d = NSDictionary(contentsOf: loginCheckAgent), let args = d["ProgramArguments"] as? [String], args.first != binary else { return }
    setLoginCheck(true)
}

/// --login-check: runs without a window. Waits for the desktop to settle, checks, shows at most one dialog.
func runLoginCheck() {
    Thread.sleep(forTimeInterval: 20)
    let facts = SystemFacts.probe()
    let dismissed = UserDefaults.standard.dictionary(forKey: "healthDismissed") as? [String: String] ?? [:]
    let issues = healthIssues(facts).filter { dismissed[$0.code] != $0.key }
    guard !issues.isEmpty else { return }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = issues.count == 1 ? String(localized: "IntelXe Manager: one thing needs attention")
                                          : String(localized: "IntelXe Manager: \(issues.count) things need attention")
    alert.informativeText = issues.map { "• " + $0.text }.joined(separator: "\n\n")
    alert.addButton(withTitle: String(localized: "Open IntelXe Manager"))
    alert.addButton(withTitle: String(localized: "Later"))
    alert.addButton(withTitle: String(localized: "Don't remind me of these"))
    switch alert.runModal() {
    case .alertFirstButtonReturn:
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = ["--section", issues.contains { $0.code.hasPrefix("ssv") || $0.code.hasPrefix("kext") } ? "driver" : "system"]
        let done = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in done.signal() }
        _ = done.wait(timeout: .now() + 10)
    case .alertThirdButtonReturn:
        var d = dismissed
        for i in issues { d[i.code] = i.key }
        UserDefaults.standard.set(d, forKey: "healthDismissed")
    default: break
    }
}
