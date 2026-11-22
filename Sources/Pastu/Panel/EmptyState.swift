import PastuCore
import SwiftUI

/// What the list area shows when there is nothing to list: no history, an empty filter, or a search without hits.
struct EmptyState: View {
    let query: String
    let filter: ClipFilter

    var body: some View {
        Group {
            if !query.isEmpty {
                VStack(spacing: 0) {
                    ContentUnavailableView.search(text: query)
                        .frame(height: 90)
                    if filter != .all {
                        Text("Searching \(filter.title) only. Press Tab to change.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                switch filter {
                case .all:
                    ContentUnavailableView(
                        "Nothing copied yet", systemImage: "doc.on.clipboard",
                        description: Text("Copy something, then press ⌘⇧V."))
                case .text:
                    ContentUnavailableView("No text yet", systemImage: "text.alignleft")
                case .links:
                    ContentUnavailableView("No links yet", systemImage: "link")
                case .images:
                    ContentUnavailableView("No images yet", systemImage: "photo")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
