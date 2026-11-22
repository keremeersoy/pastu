import PastuCore
import SwiftUI

/// The header row: search symbol, search field, clear button (only with a query) and the filter control.
/// Key handling stays with the caller; key presses bubble up from the focused field to this view.
struct SearchHeader: View {
    @Binding var query: String
    @Binding var filter: ClipFilter
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused(focused)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .focusable(false)
                .accessibilityLabel("Clear search")
            }
            FilterControl(selection: $filter)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }
}
