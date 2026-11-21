import PastuCore
import SwiftUI

/// "All / Text / Links / Images" chips above the list. Tab cycles through them; they are not clickable on purpose
/// (the search field keeps keyboard focus).
struct FilterBar: View {
    let selected: ClipFilter

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ClipFilter.allCases, id: \.self) { filter in
                Text(filter.title)
                    .font(.caption.weight(filter == selected ? .semibold : .regular))
                    .foregroundStyle(filter == selected ? Color.primary : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(filter == selected ? Color.accentColor.opacity(0.35) : .clear))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}
