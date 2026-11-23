import SwiftUI

struct HintFooter: View {
    let canAutoPaste: Bool
    let notice: String?
    @Binding var showsShortcuts: Bool
    var queueCount = 0
    var onPasteQueue: () -> Void = {}
    var onClearQueue: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            if let notice {
                // A one-off message replaces the hints until the user moves on.
                Label(notice, systemImage: "info.circle.fill")
                    .foregroundStyle(Color.accentColor)
                Spacer()
                queueControls
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
        queueControls
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

    /// "⌘↩ Paste queue (3)" and a Clear button, while something is queued; also next to a notice, so adding to the
    /// queue (which shows a notice) does not hide them.
    @ViewBuilder
    private var queueControls: some View {
        if queueCount > 0 {
            // Never focusable, like the shortcuts button: the search field keeps the keyboard.
            Button(action: onPasteQueue) { hintLabel("⌘↩", "Paste queue (\(queueCount))") }
                .buttonStyle(.plain).focusable(false)
                .accessibilityLabel("Paste queue (\(queueCount))")
            Button("Clear", action: onClearQueue)
                .buttonStyle(.plain).focusable(false)
                .accessibilityLabel("Clear queue")
        }
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
