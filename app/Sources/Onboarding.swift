// SPDX-License-Identifier: MIT
// The setup assistant: from a fresh macOS install (OpenCore with the B580 on its firmware's framebuffer, the EFI on a
// USB stick or a disk) to a verified driver, one page at a time. The page is worked out from the machine each time the
// assistant opens, so it picks up where the last restart left it: the EFI settings (SIP, AMFI, quirks: efi.sh stage 2),
// the driver package (install.sh), IntelXe.kext in the EFI (stage 4), then a GPU test. Every change goes through the
// same scripts and password dialogs as the other pages; nothing here writes on its own.
import AppKit
import SwiftUI

enum SetupStep: Equatable {
    case blocked(String)
    case efiSettings, driver, efiKext, verify, done

    var number: Int {
        switch self { case .blocked: return 0; case .efiSettings: return 1; case .driver: return 2; case .efiKext: return 3; case .verify: return 4; case .done: return 5 }
    }
}

extension Manager {
    /// Where the machine stands, from what refresh() found.
    var setupStep: SetupStep {
        let f = facts
        if f.architecture != "x86_64" { return .blocked(String(localized: "This Mac is not an x86_64 machine: the driver is for Intel-based hackintoshes.")) }
        if f.macOSMajor != 26 && f.macOSMajor != 15 { return .blocked(String(localized: "The driver has packages for macOS 26 Tahoe and macOS 15 Sequoia; this is macOS \(f.macOS).")) }
        if !f.hasCard { return .blocked(String(localized: "No Arc B580 was found on the PCI bus. Check that the card is seated, has its power cables, and that the BIOS has Above 4G decoding and Resizable BAR on.")) }
        if !(f.sipRelaxed && f.amfiRelaxed) { return .efiSettings }
        if f.installedVersion == nil && !f.driverFilesPresent { return .driver }
        if !f.kextLoaded { return .efiKext }
        if testResults.isEmpty || testing != nil { return .verify }
        return .done
    }

    func restartNow() {
        NSAppleScript(source: "tell application \"System Events\" to restart")?.executeAndReturnError(nil)
    }
}

final class SetupState: ObservableObject {
    @Published var downloading = false
    @Published var confirmInstall = false
    @Published var loginCheck = loginCheckEnabled()
}

struct SetupView: View {
    @EnvironmentObject var manager: Manager
    @StateObject var st = SetupState()
    var close: () -> Void

    var body: some View {
        let step = manager.setupStep
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Setup assistant").font(.title2.bold())
                Spacer()
                // the page headings carry the same numbers (1. Prepare OpenCore ... 5. Done)
                Text(step.number == 0 ? String(localized: "Before you start") : String(localized: "Step \(step.number) of 5")).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(step.number), total: 5)
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 12) { page(step) }.frame(maxWidth: .infinity, alignment: .leading) }
            if let busy = manager.busy { HStack { ProgressView().controlSize(.small); Text(busy).foregroundStyle(.secondary) } }
            if let r = manager.lastResult { Text(r).font(.callout) }
            Divider()
            HStack {
                Button("Check again") { Task { await manager.refresh() } }.disabled(manager.probing)
                Spacer()
                Button(step == .done ? "Finish" : "Close, continue later") {
                    if step == .done { UserDefaults.standard.set(true, forKey: "setupDone") }
                    close()
                }
            }
        }
        .padding(22)
        .frame(width: 620, height: 520)
        .disabled(manager.busy != nil)
    }

    @ViewBuilder func page(_ step: SetupStep) -> some View {
        switch step {
        case .blocked(let why):
            Label(why, systemImage: "xmark.octagon").foregroundStyle(.red)
            Text("The assistant continues once this is solved. The install guide covers the BIOS and OpenCore preparation.")
            Link("Open the install guide", destination: URL(string: "https://github.com/\(repository)/blob/main/release/README-INSTALL.md")!)
        case .efiSettings:
            Text("1. Prepare OpenCore").font(.headline)
            Text("The driver needs System Integrity Protection relaxed and AMFI's boot-arg in your OpenCore config, plus a few quirks. The assistant writes them into the EFI you booted from, after a backup, and shows every change before it makes it.")
            efiStep(.settings)
        case .driver:
            Text("2. Install the driver").font(.headline)
            Text("The package puts the framebuffer, the accelerator and the Metal driver into /Library and rebuilds the kernel collection (a few minutes). It backs up what it replaces.")
            if let p = manager.package {
                Label(String(localized: "Package \(p.directory.lastPathComponent) is ready."), systemImage: "checkmark.circle").foregroundStyle(.green)
                Button("Install the driver") { st.confirmInstall = true }.buttonStyle(.borderedProminent)
                    .alert(DriverAction.install.title, isPresented: $st.confirmInstall) {
                        Button(DriverAction.install.title) { manager.perform(.install) }
                        Button("Cancel", role: .cancel) {}
                    } message: { Text(DriverAction.install.explanation) }
            } else if let rel = manager.release {
                Button(String(localized: "Download \(rel.tag_name)")) {
                    st.downloading = true
                    Task { await manager.downloadLatest(zink: false); st.downloading = false }
                }.buttonStyle(.borderedProminent).disabled(st.downloading)
                if st.downloading { ProgressView().controlSize(.small) }
            } else {
                Text(manager.releaseError ?? String(localized: "Looking for the latest release…")).foregroundStyle(.secondary)
                Button("Look again") { Task { await manager.checkForUpdate() } }
            }
            Text("When it has finished: restart, then open this assistant again.").font(.callout).foregroundStyle(.secondary)
            if manager.rebootNeeded { Button("Restart now") { manager.restartNow() }.buttonStyle(.borderedProminent) }
        case .efiKext:
            Text("3. Add IntelXe.kext to OpenCore").font(.headline)
            Text("The last piece loads before macOS: IntelXe.kext and SSDT-ARCOFF go into the EFI and its config. The EFI page shows the plan and applies it.")
            efiStep(.apply)
            Text("If the next boot stops at the Apple logo, choose the previous entry or your USB stick in the OpenCore picker: the backup is kept, and the EFI page can put it back.")
                .font(.callout).foregroundStyle(.secondary)
        case .verify:
            Text("4. Check that it works").font(.headline)
            Text("The driver is loaded. A quick test checks that the GPU computes, draws and decodes video correctly and measures it.")
            Button("Run the quick GPU test") { manager.runTest() }.buttonStyle(.borderedProminent).disabled(manager.testing != nil)
            if let s = manager.testing { HStack { ProgressView().controlSize(.small); Text(s).foregroundStyle(.secondary) } }
        case .done:
            let bad = manager.testResults.filter { $0.state == .bad }.count, warn = manager.testResults.filter { $0.state == .warning }.count
            Text("5. Done").font(.headline)
            if bad == 0 {
                Label(warn == 0 ? String(localized: "Everything works.") : String(localized: "It works; \(warn) result(s) are below what the card should reach (see the Report page)."),
                      systemImage: "checkmark.seal").foregroundStyle(warn == 0 ? .green : .orange)
            } else {
                Label(String(localized: "\(bad) test(s) failed. The Report page shows which, and makes a diagnostics report for a bug report."), systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
            Text("Optional next steps:").padding(.top, 6)
            Button("HiDPI sizes and Variable refresh (Display page)") { manager.requestedSection = .display; close() }
            Button("Safari on the GPU: the system-volume copy (Driver page)") { manager.requestedSection = .driver; close() }
            Text(manager.ssv.state == .inUse || manager.ssv.state == .notPackage ? String(localized: "Installed.")
                 : String(localized: "Without it Safari draws in software. It needs OpenCore's Apple Secure Boot off first (EFI page); a macOS update removes it again."))
                .font(.callout).foregroundStyle(.secondary).padding(.leading, 4)
            Button("Minecraft and other LWJGL games through Zink (OpenGL page)") { manager.requestedSection = .zink; close() }
            Button("GPU clock and temperature in the menu bar (Monitor page)") { manager.requestedSection = .monitor; close() }
            CaptionedToggle(title: "Check the driver at login", caption: "A dialog after login only when something needs attention, such as a macOS update that removed the system-volume copy.",
                            isOn: Binding(get: { st.loginCheck }, set: { setLoginCheck($0); st.loginCheck = loginCheckEnabled() }))
                .padding(.top, 4)
            if manager.efi["efi_disk_location"].lowercased().contains("external") {
                Label("Your EFI is on a USB stick. Once everything works you can copy it to the EFI partition of the macOS disk (install guide, the last stage), and keep the stick as a fallback.",
                      systemImage: "externaldrive").font(.callout)
            }
        }
    }

    /// The package is needed first (the EFI files and efi.sh come from it): download it here when it is missing.
    @ViewBuilder var packageGate: some View {
        if let rel = manager.release {
            Text("First the driver package is downloaded: the EFI files come from it.").font(.callout)
            Button(String(localized: "Download \(rel.tag_name)")) {
                st.downloading = true
                Task { await manager.downloadLatest(zink: false); st.downloading = false; await manager.refresh() }
            }.buttonStyle(.borderedProminent).disabled(st.downloading)
            if st.downloading { ProgressView().controlSize(.small) }
        } else {
            Text(manager.releaseError ?? String(localized: "Looking for the latest release…")).foregroundStyle(.secondary)
            Button("Look again") { Task { await manager.checkForUpdate() } }
        }
    }

    /// An EFI change in place: where, the plan efi.sh made (exactly what will change), Apply, then restart.
    @ViewBuilder func efiStep(_ action: EFIAction) -> some View {
        if manager.package == nil {
            packageGate
        } else {
            efiLocation
            let e = manager.efi
            if e.found && !e.mounted {
                Button("Mount the EFI partition (asks for your password)") { manager.performEFI(.mount) }.buttonStyle(.borderedProminent)
            } else if e.found, let plan = manager.efiPlans[action] {
                Text("What will change (a backup of the whole EFI folder is made first):").font(.callout)
                ScrollView { PlanText(plan: plan).padding(8) }
                    .frame(maxHeight: 170)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                if plan.changes {
                    Button(String(localized: "Apply (asks for your password)")) { manager.performEFI(action) }.buttonStyle(.borderedProminent)
                } else {
                    Label("Nothing left to change in the EFI.", systemImage: "checkmark.circle").foregroundStyle(.green)
                }
            } else if e.found {
                Text("Reading the EFI…").foregroundStyle(.secondary)
            } else {
                Button("Open the EFI page to choose it") { manager.requestedSection = .efi; close() }
            }
            Text("Then restart and open this assistant again: it continues from there.").font(.callout).foregroundStyle(.secondary)
            if manager.rebootNeeded { Button("Restart now") { manager.restartNow() }.buttonStyle(.borderedProminent) }
            else { Button("Restart now") { manager.restartNow() } }
        }
    }

    @ViewBuilder var efiLocation: some View {
        let e = manager.efi
        if e.found {
            let usb = e["efi_disk_location"].lowercased().contains("external")
            Label(String(localized: "OpenCore EFI: \(e["efi_description"].isEmpty ? e["efi_partition"] : e["efi_description"])") + (usb ? String(localized: " (USB stick: that is fine)") : ""),
                  systemImage: usb ? "externaldrive" : "internaldrive")
        } else {
            Label("The EFI you booted from was not found yet: choose it on the EFI page.", systemImage: "questionmark.circle").foregroundStyle(.orange)
        }
    }
}
