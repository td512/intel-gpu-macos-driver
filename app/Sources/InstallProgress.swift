// SPDX-License-Identifier: MIT
// The steps of an install.sh run (install, repair, undo, uninstall), read from what install.sh prints as it works:
// each step begins at a line install.sh writes (its "== ..." headings and "ok" lines), so the list follows the script
// and nothing here guesses at timing. The full output stays one click away.
import SwiftUI

struct DriverRun: Equatable {
    let action: DriverAction
    /// where this run's output begins in Manager.log
    let logStart: Int
    let start = Date()
    var end: Date?
    var finished = false
    var succeeded = false
    var cancelled = false
    var dismissed = false
}

struct InstallStep {
    let title: String
    /// output that shows the step has begun; empty = begun from the start
    let marker: String
}

extension DriverAction {
    /// install.sh's steps for this action, in order (none for the check, which takes seconds)
    var steps: [InstallStep] {
        let rootPrompt = InstallStep(title: String(localized: "Administrator password"), marker: "")
        let checks = InstallStep(title: String(localized: "Check the system and the package"), marker: "== intel-gpu-macos-driver")
        let rebuild = InstallStep(title: String(localized: "Rebuild the Auxiliary Kernel Collection (a few minutes)"), marker: "== rebuilding the Auxiliary Kernel Collection")
        switch self {
        case .check: return []
        case .install:
            return [rootPrompt, checks,
                    InstallStep(title: String(localized: "Back up what it replaces"), marker: "== 0 problem(s)"),
                    InstallStep(title: String(localized: "Copy the kexts into /Library/Extensions"), marker: "== backup:"),
                    InstallStep(title: String(localized: "Copy the Metal driver into /Library/GPUBundles"), marker: "GPUBundles/NVMTLDriverLib.bundle"),
                    rebuild]
        case .repair:
            return [rootPrompt, checks, InstallStep(title: String(localized: "Put back the files that differ"), marker: "== 0 problem(s)"), rebuild]
        case .undo:
            return [rootPrompt, InstallStep(title: String(localized: "Restore the last backup"), marker: "== restoring"), rebuild]
        case .uninstall:
            return [rootPrompt, InstallStep(title: String(localized: "Remove the driver's files"), marker: "ok    removed"), rebuild]
        }
    }
}

enum StepState { case pending, running, done, skipped, failed }

/// Each step's state from the run's output so far: the last step that has begun is the one running (or the one that
/// failed); earlier ones are done, or skipped when their line never came (a repair without kexts rebuilds nothing).
func stepStates(_ steps: [InstallStep], output: String, run: DriverRun) -> [StepState] {
    let begun = steps.map { $0.marker.isEmpty || output.contains($0.marker) }
    let last = begun.lastIndex(of: true) ?? 0
    return steps.indices.map { i in
        if run.finished && run.succeeded { return begun[i] ? .done : .skipped }
        if i < last { return begun[i] ? .done : .skipped }
        if i == last { return run.finished ? .failed : .running }
        return run.finished ? .skipped : .pending
    }
}

/// The step list with checkmarks, the elapsed time, how it ended, and the run's whole output in a disclosure group.
struct DriverRunView: View {
    @EnvironmentObject var manager: Manager
    let run: DriverRun
    var closable = false
    @StateObject private var showLog = Flag()

    var body: some View {
        let output = String(manager.log.dropFirst(run.logStart))
        let steps = run.action.steps
        let states = stepStates(steps, output: output, run: run)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.action.title).font(.headline)
                Spacer()
                TimelineView(.periodic(from: run.start, by: 1)) { context in
                    Text(elapsed(to: run.end ?? context.date)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
                if closable && run.finished {
                    Button { manager.driverRun?.dismissed = true } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.borderless).help(Text("Close")).accessibilityLabel(Text("Close"))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        icon(states[i]).frame(width: 18, height: 16)
                        Text(steps[i].title)
                            .foregroundStyle(states[i] == .pending || states[i] == .skipped ? .secondary : .primary)
                            .fontWeight(states[i] == .running ? .semibold : .regular)
                    }
                    .animation(.easeInOut(duration: 0.25), value: states[i])
                }
            }
            if run.finished {
                Label(resultText, systemImage: run.succeeded ? "checkmark.seal.fill" : run.cancelled ? "xmark.circle" : "exclamationmark.triangle.fill")
                    .foregroundStyle(run.succeeded ? Color.green : run.cancelled ? Color.secondary : Color.red)
            }
            DisclosureGroup(isExpanded: $showLog.on) {
                ScrollView {
                    Text(output.isEmpty ? String(localized: "Nothing yet.") : output)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(height: 150)
                .defaultScrollAnchor(.bottom)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
            } label: {
                Text("Full log").font(.callout)
            }
        }
    }

    var resultText: String {
        if run.cancelled { return String(localized: "Cancelled. Nothing changed.") }
        if !run.succeeded { return String(localized: "It did not finish. See the log.") }
        return run.action.needsReboot ? String(localized: "Finished. Restart to use the change.") : String(localized: "Finished.")
    }

    @ViewBuilder func icon(_ state: StepState) -> some View {
        switch state {
        case .pending: Image(systemName: "circle").foregroundStyle(.tertiary)
        case .running: ProgressView().controlSize(.small).scaleEffect(0.8)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped: Image(systemName: "minus.circle").foregroundStyle(.tertiary)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    func elapsed(to date: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(run.start)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
