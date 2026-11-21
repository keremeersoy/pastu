import PastuCore
import SwiftUI

enum PanelMetrics {
    static let size = CGSize(width: 780, height: 460)
    static let listWidth: CGFloat = 340
}

struct PanelView: View {
    let model: ClipListModel
    let canAutoPaste: Bool
    let onSubmit: () -> Void
    var onIgnoreApp: () -> Void = {}
    /// Loads a picture clip's PNG bytes; the default shows a placeholder.
    var imageData: (Int64) -> Data? = { _ in nil }

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
                .onKeyPress(.tab) { model.cycleFilter(); return .handled }
                .onKeyPress(characters: .decimalDigits, phases: .down) { press in
                    // ⌘1-9 pastes the nth row directly.
                    guard press.modifiers.contains(.command),
                          let digit = Int(press.characters), (1...9).contains(digit),
                          model.select(row: digit - 1) else { return .ignored }
                    onSubmit()
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "iI"), phases: .down) { press in
                    // ⌘I stops recording copies from the selected clip's source app.
                    guard press.modifiers.contains(.command) else { return .ignored }
                    onIgnoreApp()
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "pP"), phases: .down) { press in
                    // ⌘P pins or unpins the selected clip.
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.togglePinSelected()
                    return .handled
                }

            FilterBar(selected: model.filter)

            Divider()

            if model.clips.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    list.frame(width: PanelMetrics.listWidth)
                    Divider()
                    PreviewPane(clip: model.selectedClip, imageData: imageData)
                }
            }

            Divider()
            HintFooter(canAutoPaste: canAutoPaste, notice: model.notice)
        }
        .frame(width: PanelMetrics.size.width, height: PanelMetrics.size.height)
        .panelShell()
        .onAppear { searchFocused = true }
    }

    private var emptyMessage: String {
        if !model.query.isEmpty { return "No matches" }
        switch model.filter {
        case .all: return "Nothing copied yet"
        case .text: return "No text clips"
        case .links: return "No links"
        case .images: return "No images"
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.clips.enumerated()), id: \.element.id) { index, clip in
                        ClipRow(
                            clip: clip, isSelected: index == model.selectedIndex,
                            shortcutDigit: index < 9 ? index + 1 : nil, imageData: imageData
                        )
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
