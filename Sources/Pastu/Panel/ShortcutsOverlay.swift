import SwiftUI

/// Every shortcut in one place, drawn over the panel on a calm surface (never directly on glass).
/// It is display-only and never focusable, so the search field keeps the keyboard.
struct ShortcutsOverlay: View {
    private static let rows: [(keys: String, action: String)] = [
        ("↩", "Paste"),
        ("⌘1–9", "Paste row"),
        ("⌘P", "Pin"),
        ("⌘⌫", "Delete"),
        ("⌘I", "Ignore app"),
        ("⇥ / ⇧⇥", "Filter"),
        ("↑ ↓", "Select"),
        ("⌘↑ ⌘↓", "First / last"),
        ("Page Up / Down", "Page"),
        ("esc", "Clear search / close"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard Shortcuts").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Self.rows, id: \.action) { row in
                    GridRow {
                        Keycap(text: row.keys).gridColumnAlignment(.trailing)
                        Text(row.action).font(.callout)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text("⌘/ closes this list").font(.caption).foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: PanelMetrics.innerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PanelMetrics.innerRadius, style: .continuous)
                .strokeBorder(.separator)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard shortcuts")
    }
}

/// A key name on a small rounded quiet background.
struct Keycap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
