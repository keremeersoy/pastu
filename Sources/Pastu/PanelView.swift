import PastuCore
import SwiftUI

struct PanelView: View {
    let model: ClipListModel
    let onSubmit: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search clipboard history", text: Bindable(model).query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(14)
                .focused($searchFocused)
                .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
                .onKeyPress(.return) { onSubmit(); return .handled }
                .onKeyPress(characters: .decimalDigits, phases: .down) { press in
                    // ⌘1-9 pastes the nth row directly.
                    guard press.modifiers.contains(.command),
                          let digit = Int(press.characters), (1...9).contains(digit),
                          model.select(row: digit - 1) else { return .ignored }
                    onSubmit()
                    return .handled
                }

            Divider()

            if model.clips.isEmpty {
                Text(model.query.isEmpty ? "Nothing copied yet" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
        }
        .frame(width: 640, height: 420)
        .panelShell()
        .onAppear { searchFocused = true }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.clips.enumerated()), id: \.element.id) { index, clip in
                        ClipRow(clip: clip, isSelected: index == model.selectedIndex, shortcutDigit: index < 9 ? index + 1 : nil)
                            .id(clip.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selectedIndex) {
                if let id = model.selectedClip?.id { proxy.scrollTo(id) }
            }
        }
    }
}

private struct ClipRow: View {
    let clip: StoredClip
    let isSelected: Bool
    let shortcutDigit: Int?

    var body: some View {
        HStack {
            Text(clip.text.replacingOccurrences(of: "\n", with: " "))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let shortcutDigit {
                Text("⌘\(shortcutDigit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.35) : .clear)
            )
    }
}

private extension View {
    /// Liquid Glass only on the panel shell (macOS 26+), a material on older systems.
    @ViewBuilder
    func panelShell() -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}
