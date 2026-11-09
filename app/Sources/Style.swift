// SPDX-License-Identifier: MIT
// Shared pieces of the pages' look: a caption with its detail behind an (i) button, a path on one line with Show in
// Finder, a coloured status badge, a tinted card background. Plain observable state only (no SwiftUI macros: the app
// builds with the command line tools alone).
import AppKit
import SwiftUI

final class Flag: ObservableObject {
    @Published var on: Bool
    init(_ on: Bool = false) { self.on = on }
}

/// An (i) button that shows a longer explanation in a popover.
struct InfoButton: View {
    let text: Text
    @StateObject private var shown = Flag()
    init(_ text: Text) { self.text = text }
    init(_ key: LocalizedStringKey) { self.text = Text(key) }
    init(verbatim: String) { self.text = Text(verbatim) }
    var body: some View {
        Button { shown.on.toggle() } label: {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("More information"))
        .help(Text("More information"))
        .popover(isPresented: $shown.on, arrowEdge: .bottom) {
            text.font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 340, alignment: .leading)
                .padding(14)
                .textSelection(.enabled)
        }
    }
}

/// One short secondary line, and the long explanation behind an (i) button.
struct Caption: View {
    let text: Text
    var detail: Text?
    init(_ text: LocalizedStringKey, detail: LocalizedStringKey? = nil) { self.text = Text(text); self.detail = detail.map { Text($0) } }
    init(text: Text, detail: Text?) { self.text = text; self.detail = detail }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            text.font(.callout).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            if let detail { InfoButton(detail) }
        }
    }
}

/// A path as the user knows it: ~ for the home folder.
func displayPath(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

/// A file or folder on one line, truncated in the middle, with the whole path as help and a Show in Finder button.
struct PathRow: View {
    let title: LocalizedStringKey
    let path: String
    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Text(displayPath(path))
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .help(path)
                Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help(Text("Show in Finder"))
                .accessibilityLabel(Text("Show in Finder"))
            }
        }
    }
}

/// A capsule with a dot and a short state, in the state's colour.
struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.callout.weight(.semibold)).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .foregroundStyle(color)
        .background {
            Capsule(style: .continuous).fill(color.opacity(0.16))
        }
    }
}

/// A rounded card filled with a light wash of its colour, with an edge that stays visible in the light appearance.
struct TintedCard: ViewModifier {
    let tint: Color
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(tint.opacity(0.28)))
    }
}

extension View {
    func tintedCard(_ tint: Color) -> some View { modifier(TintedCard(tint: tint)) }
}

/// The colour for a neutral card or state: grey that keeps its contrast on both appearances.
let neutralTint = Color(nsColor: .systemGray)
