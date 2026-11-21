import SwiftUI

struct HintFooter: View {
    let canAutoPaste: Bool
    let notice: String?

    var body: some View {
        HStack(spacing: 16) {
            if let notice {
                // A one-off message replaces the hints until the user moves on.
                Label(notice, systemImage: "info.circle.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                hints
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var hints: some View {
        if canAutoPaste {
            Text("↩ Paste")
        } else {
            // Without the Accessibility permission Pastu can only copy; the user presses ⌘V themselves.
            Label("↩ Copies only: enable Accessibility to auto-paste", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        Text("⌘1–9 Quick paste")
        Text("⌘P Pin")
        Text("⌘⌫ Delete")
        Text("⌘I Ignore app")
        Text("⇥ Filter")
        Text("↑↓ Select")
        Text("esc Close")
    }
}
