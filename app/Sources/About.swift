// SPDX-License-Identifier: MIT
// The About window (app menu > About IntelXe Manager): version, the project's page, the licences and the credits, as
// the repository's README states them.
import AppKit
import SwiftUI

struct AboutMenuItem: View {
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Button("About IntelXe Manager") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
        }
    }
}

struct AboutView: View {
    var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–" }
    static let credits: [(name: String, url: String?, what: LocalizedStringKey)] = [
        ("nullmoth (NullMoth Systems)", "https://github.com/nullmoth/nvidia-macos-driver",
         "The Metal plugin, the AIR to SPIR-V translator and the accelerator kexts this stack is built on."),
        ("metal2vulkan, Anees Iqbal", "https://github.com/steelbrain/metal2vulkan", "The translator nullmoth's is based on."),
        ("Linux xe and i915 (Intel)", nil, "The kernel driver follows them."),
        ("Mesa", "https://mesa3d.org", "ANV, the Vulkan driver."),
        ("Emil J. Tywoniak (widlarizer/mesa)", "https://github.com/widlarizer/mesa", "The Xe2 VDEnc work."),
        ("FFmpeg", nil, "The Vulkan video code the VideoToolbox codecs use."),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable().frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text(verbatim: "IntelXe Manager").font(.title.weight(.semibold))
                Text("Version \(version)").foregroundStyle(.secondary).textSelection(.enabled)
            }
            Text("Installs and manages the IntelXe driver for the Intel Arc B580 on macOS.")
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Link(destination: URL(string: "https://github.com/\(repository)")!) {
                Label("github.com/\(repository)", systemImage: "link")
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label("License", systemImage: "doc.plaintext").font(.headline)
                Text("This app is under the MIT License. Parts of the driver are under PolyForm Noncommercial 1.0.0 and LGPL-3.0-or-later: the repository and the release packages are for noncommercial use.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Label("Credits", systemImage: "heart").font(.headline).padding(.top, 4)
                ForEach(Self.credits, id: \.name) { credit in
                    VStack(alignment: .leading, spacing: 1) {
                        if let url = credit.url.flatMap(URL.init(string:)) {
                            Link(credit.name, destination: url).font(.callout.weight(.medium))
                        } else {
                            Text(verbatim: credit.name).font(.callout.weight(.medium))
                        }
                        Text(credit.what).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Intel, Arc, Apple, macOS and Metal are trademarks of their owners.")
                    .font(.caption2).foregroundStyle(.tertiary).padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(width: 420)
    }
}
