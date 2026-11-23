import PastuCore
import SwiftUI

/// "All / Text / Links / Images" on the trailing side of the header. Clickable, but never focusable, so the
/// search field keeps keyboard focus; Tab and Shift-Tab still cycle through the same filters.
struct FilterControl: View {
    @Binding var selection: ClipFilter
    @Environment(\.panelStyle) private var style
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        // With Reduce Transparency the shell is an opaque fill, so the plain segmented control matches it.
        if style == .glass, !reduceTransparency, #available(macOS 26, *) {
            GlassFilterButtons(selection: $selection)
        } else {
            Picker("Filter", selection: $selection) {
                ForEach(ClipFilter.allCases, id: \.self) { filter in
                    // The macOS segmented control shows only the titles; the symbols appear on the glass buttons.
                    FilterLabel(filter: filter).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
            .focusable(false)
        }
    }
}

/// macOS 26: one glass button per filter; the container lets neighbouring glass shapes blend.
@available(macOS 26, *)
private struct GlassFilterButtons: View {
    @Binding var selection: ClipFilter

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(ClipFilter.allCases, id: \.self) { filter in
                    button(for: filter)
                }
            }
        }
    }

    /// One shape and one padding for every chip, selected or not. The stock `.glass` and `.glassProminent` styles
    /// pad differently, which made the selected chip shrink; the selected chip is now only tinted.
    private func button(for filter: ClipFilter) -> some View {
        let isSelected = filter == selection
        return Button { selection = filter } label: {
            FilterLabel(filter: filter)
                .font(.callout)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: Capsule())
        .focusable(false)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FilterLabel: View {
    let filter: ClipFilter

    var body: some View {
        if let symbol = filter.symbolName {
            Label(filter.title, systemImage: symbol)
        } else {
            Text(filter.title)
        }
    }
}

extension ClipFilter {
    /// "All" has no symbol on purpose: it is the default and reads best as a plain word.
    var symbolName: String? {
        switch self {
        case .all: nil
        case .text: "text.alignleft"
        case .links: "link"
        case .images: "photo"
        }
    }
}
