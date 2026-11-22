import SwiftUI

struct HintFooter: View {
    let canAutoPaste: Bool
    let notice: String?
    @Binding var showsShortcuts: Bool

    var body: some View {
        HStack(spacing: 16) {
            if let notice {
                // A one-off message replaces the hints until the user moves on.
                Label(notice, systemImage: "info.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Spacer()
            } else {
                hints
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var hints: some View {
        // Without the Accessibility permission Pastu only copies; the banner above explains how to fix it.
        hint("↩", canAutoPaste ? "Paste" : "Copy")
        hint("⌘P", "Pin")
        hint("⌘⌫", "Delete")
        Spacer()
        // Never focusable: the search field keeps the keyboard. ⌘/ does the same from there.
        Button {
            showsShortcuts.toggle()
        } label: {
            hintLabel("⌘/", "Shortcuts")
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel("Keyboard shortcuts")
    }

    private func hint(_ keys: String, _ title: String) -> some View {
        hintLabel(keys, title).accessibilityElement(children: .combine)
    }

    private func hintLabel(_ keys: String, _ title: String) -> some View {
        HStack(spacing: 5) {
            Keycap(text: keys)
            Text(title)
        }
    }
}
