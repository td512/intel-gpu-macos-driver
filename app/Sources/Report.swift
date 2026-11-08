// SPDX-License-Identifier: MIT
// The Report page: tools/report/collect-macos.sh, carried in the app, makes the diagnostics archive (on the Desktop) and
// prints what it recognised as wrong ("Warning <code>: <text>"); the page lists those with a way to fix each one the
// app can fix, and opens the issue forms with the report ID filled in. The script only reads; administrator mode runs
// it as root (the OpenCore config from the EFI partitions, the driver's root-only counters, the CPU clock), and the
// user's own name is still removed from the archive (XE_REPORT_USER).
import AppKit
import Foundation
import SwiftUI

struct ReportWarning: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let text: String
}

/// Issue forms; GitHub fills a form field from a query parameter named after the field's id.
func issueFormURL(template: String, field: String, value: String?) -> URL {
    var c = URLComponents(string: "https://github.com/\(repository)/issues/new")!
    c.queryItems = [URLQueryItem(name: "template", value: template)]
    if let value { c.queryItems?.append(URLQueryItem(name: field, value: value)) }
    return c.url!
}

extension Manager {
    func createReport(acpi: Bool, probe: Bool, admin: Bool) {
        guard let script = Bundle.main.url(forResource: "collect-macos", withExtension: "sh") else { return }
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        var args = ["--out", desktop.path]
        if acpi { args.append("--acpi") }
        if probe { args.append("--probe") }
        var command = "/bin/sh \(shellQuoted(script.path)) " + args.map(shellQuoted).joined(separator: " ")
        if admin { command = "XE_REPORT_USER=\(shellQuoted(NSUserName())) " + command }
        let start = log.count
        reportWarnings = []
        perform(title: String(localized: "Create a diagnostics report"), command: command, needsRoot: admin, then: { result in
            let lines = String(self.log.dropFirst(start)).split(separator: "\n").map(String.init)
            let field = { (name: String) in lines.first { $0.hasPrefix(name) }.map { String($0.dropFirst(name.count)).trimmingCharacters(in: .whitespaces) } }
            self.reportWarnings = lines.compactMap { line in
                guard line.hasPrefix("Warning "), let colon = line.firstIndex(of: ":") else { return nil }
                let code = String(line[line.index(line.startIndex, offsetBy: 8)..<colon])
                return ReportWarning(code: code, text: String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces))
            }
            if result.cancelled {
                self.lastResult = String(localized: "Cancelled. No report was written.")
            } else if result.succeeded, let id = field("Report ID:"), let file = field("File:") {
                self.reportID = id; self.reportFile = file
                self.lastResult = String(localized: "Report \(id) is on the Desktop. Attach it to a new issue and put the ID in the form.")
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file)])
            } else {
                self.lastResult = String(localized: "No report was written. See the log.")
            }
        })
    }
}

struct ReportView: View {
    @EnvironmentObject var manager: Manager
    @AppStorage("reportACPI") var acpi = false
    @AppStorage("reportProbe") var probe = false
    @AppStorage("reportAdmin") var admin = false

    var body: some View {
        Form {
            Section2(title: "Diagnostics report") {
                Text("Collects what we need to find a problem: the hardware, the driver's state, logs, kernel panics and the OpenCore config. It changes nothing and uploads nothing. Serial numbers, names, network addresses and Wi-Fi names are removed before the file is written. It takes about a minute; the file goes on your Desktop.")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("Administrator mode (asks for your password): adds the OpenCore config from the EFI partitions, the driver's root-only counters and the CPU clock", isOn: $admin)
                Toggle("ACPI tables (DSDT and SSDTs as macOS loaded them; never the tables that hold the Windows licence)", isOn: $acpi)
                Toggle("Staged-probe results (only for a GPU that is not supported yet)", isOn: $probe)
                Button("Create a diagnostics report") { manager.createReport(acpi: acpi, probe: probe, admin: admin) }
                    .keyboardShortcut(.defaultAction)
            }
            if let id = manager.reportID {
                Section2(title: "Last report") {
                    LabeledContent("Report ID") { Text(id).textSelection(.enabled).font(.body.monospaced()) }
                    HStack {
                        if let file = manager.reportFile {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file)]) }
                        }
                        Button("Copy the ID") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(id, forType: .string) }
                        Spacer()
                        Link("Report a bug", destination: issueFormURL(template: "1-bug.yml", field: "report", value: id))
                        Link("Ask for a new GPU", destination: issueFormURL(template: "2-new-hardware.yml", field: "reports", value: id))
                    }
                }
                Section2(title: "What the report found") {
                    if manager.reportWarnings.isEmpty {
                        Label("No known problem was recognised.", systemImage: "checkmark.circle").foregroundStyle(.green)
                    }
                    ForEach(manager.reportWarnings) { w in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(w.text, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                            fix(for: w)
                        }
                    }
                }
            } else {
                Section2(title: "Forms") {
                    HStack {
                        Link("Report a bug", destination: issueFormURL(template: "1-bug.yml", field: "report", value: nil))
                        Link("Ask for a new GPU", destination: issueFormURL(template: "2-new-hardware.yml", field: "reports", value: nil))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// What the app can do about a warning itself; the rest say what to do in their text.
    @ViewBuilder func fix(for w: ReportWarning) -> some View {
        switch w.code {
        case "accel-off": Button("Clear the boot guard") { manager.clearBootGuard() }
        case "hidpi-half", "hidpi-stale": Button("Open the Display page") { manager.requestedSection = .display }
        case "ssv-mesa", "ssv-build", "ssv-gone", "kext-version": Button("Open the Driver page") { manager.requestedSection = .driver }
        default: EmptyView()
        }
    }
}
