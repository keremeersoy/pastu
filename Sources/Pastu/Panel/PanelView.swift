import PastuCore
import SwiftUI

enum PanelMetrics {
    static let size = CGSize(width: 780, height: 460)
    static let listWidth: CGFloat = 320
    /// Close to Spotlight's panel on macOS 26.
    static let cornerRadius: CGFloat = 22
    /// Gap between the shell edge and inner surfaces (rows, preview).
    static let contentInset: CGFloat = 8
    /// Inner shapes are concentric with the shell.
    static var innerRadius: CGFloat { cornerRadius - contentInset }
    /// Page Up / Page Down step: roughly the rows that fit the list (panel minus header and footer, at a typical
    /// row height). Rows differ a little in height, so this is an estimate; it only has to feel like a page.
    static var rowsPerPage: Int {
        let listHeight = size.height - 52 - 32
        let rows = Int(listHeight / 42)
        return rows > 0 ? rows : 8
    }
}

struct PanelView: View {
    let model: ClipListModel
    let canAutoPaste: Bool
    var isPaused: Bool = false
    let onSubmit: () -> Void
    var onIgnoreApp: () -> Void = {}
    /// The row menu's "Copy": the selected clip goes on the clipboard without ⌘V.
    var onCopyOnly: () -> Void = {}
    /// The paused banner's "Resume" button.
    var onResume: () -> Void = {}
    /// The Accessibility banner's "Enable…" button.
    var onOpenAccessibilitySettings: () -> Void = {}
    /// Loads a picture clip's PNG bytes; the default shows a placeholder.
    var imageData: (Int64) -> Data? = { _ in nil }
    /// Whether ⌘ is held (all nine badges show). The controller starts and stops it with the panel.
    var commandKeys = CommandKeyMonitor()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool
    /// Set by "Resume" so the banner goes away at once; the view is rebuilt (and `isPaused` re-read) on every show.
    @State private var resumed = false

    private var banner: PanelBanner? {
        PanelBanner.current(canAutoPaste: canAutoPaste, isPaused: isPaused && !resumed)
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchHeader(query: Bindable(model).query, filter: Bindable(model).filter, focused: $searchFocused)
                // ⌘↑ and ⌘↓ never get here: `ClipPanel.performKeyEquivalent` handles them.
                .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
                .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
                .onKeyPress(.home) { model.moveToStart(); return .handled }
                .onKeyPress(.end) { model.moveToEnd(); return .handled }
                .onKeyPress(.pageUp) { model.movePage(-1, rowsPerPage: PanelMetrics.rowsPerPage); return .handled }
                .onKeyPress(.pageDown) { model.movePage(1, rowsPerPage: PanelMetrics.rowsPerPage); return .handled }
                .onKeyPress(.return) { onSubmit(); return .handled }
                // AppKit reports Shift-Tab as the back-tab character (U+0019), not as Tab plus Shift.
                .onKeyPress(keys: [.tab, KeyEquivalent("\u{19}")]) { press in
                    model.cycleFilter(reverse: press.modifiers.contains(.shift) || press.key.character == "\u{19}")
                    return .handled
                }
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
                .onKeyPress(characters: CharacterSet(charactersIn: "/"), phases: .down) { press in
                    // ⌘/ shows or hides the shortcuts overlay.
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.showsShortcuts.toggle()
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "pP"), phases: .down) { press in
                    // ⌘P pins or unpins the selected clip.
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.togglePinSelected()
                    return .handled
                }

            if let banner {
                BannerRow(banner: banner) {
                    switch banner {
                    case .accessibilityMissing: onOpenAccessibilitySettings()
                    case .recordingPaused:
                        resumed = true
                        onResume()
                    }
                }
            }

            // No dividers between header, content and footer: spacing and the preview's own surface separate them.
            if model.clips.isEmpty {
                EmptyState(query: model.query, filter: model.filter)
            } else {
                HStack(spacing: 0) {
                    list.frame(width: PanelMetrics.listWidth)
                    // The list's own inset already provides the gap on the leading side.
                    PreviewPane(clip: model.selectedClip, query: model.query, imageData: imageData)
                        .padding([.vertical, .trailing], PanelMetrics.contentInset)
                }
            }

            HintFooter(canAutoPaste: canAutoPaste, notice: model.notice, showsShortcuts: Bindable(model).showsShortcuts)
        }
        .overlay {
            // Centered over the whole panel, header and footer included; it cannot take focus (no focusable views inside).
            if model.showsShortcuts {
                ShortcutsOverlay().transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: model.showsShortcuts)
        // Focus stays in the search field, so VoiceOver would not notice a notice appearing: say it.
        .onChange(of: model.notice) {
            if let notice = model.notice { AccessibilityNotification.Announcement(notice).post() }
        }
        .frame(width: PanelMetrics.size.width, height: PanelMetrics.size.height)
        .panelShell()
        .onAppear { searchFocused = true }
    }

    /// Selects the row showing `clip`, then runs the action on the selection, so mouse actions go through the same
    /// paths as their keyboard shortcuts. Looked up by id at the time of the action: the list can reload while a
    /// menu is open (a new copy arrives), which would make a captured row index point at another clip.
    private func act(on clip: StoredClip, _ action: () -> Void) {
        guard let row = model.clips.firstIndex(where: { $0.id == clip.id }), model.select(row: row) else { return }
        action()
    }

    /// Paste and Copy close the panel; Pin, Delete and Ignore keep it open, like ⌘P, ⌘⌫ and ⌘I.
    @ViewBuilder
    private func rowMenu(for clip: StoredClip) -> some View {
        Button("Paste") { act(on: clip, onSubmit) }
        Button("Copy") { act(on: clip, onCopyOnly) }
        if clip.kind == .image {
            Button("Open in Preview") { act(on: clip) { PreviewOpener.shared.open(clip, imageData: imageData) } }
        }
        Divider()
        Button(clip.isPinned ? "Unpin" : "Pin") { act(on: clip, model.togglePinSelected) }
        Button("Delete") {
            act(on: clip) {
                model.deleteSelected()
                PanelCaches.forget(clip.id, model: model)
            }
        }
        Divider()
        let app = clip.sourceBundleIdentifier.map { AppLookup.name(for: $0) ?? $0 }
        Button(app.map { "Ignore “\($0)”" } ?? "Ignore App") { act(on: clip, onIgnoreApp) }
            .disabled(app == nil)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.clips.enumerated()), id: \.element.id) { index, clip in
                        let isSelected = index == model.selectedIndex
                        ClipRow(
                            clip: clip, isSelected: isSelected,
                            shortcutDigit: index < 9 ? index + 1 : nil,
                            showsShortcut: isSelected || commandKeys.isCommandHeld,
                            query: model.query, snippet: model.rowSnippet(for: clip), imageData: imageData
                        )
                            .id(clip.id)
                            // Select on the first click at once. An exclusive `onTapGesture(count: 2)` before
                            // `onTapGesture` would hold the single tap back for the double-click interval (~0.5 s),
                            // so the double tap runs alongside instead; its first click has already selected the row.
                            .onTapGesture { act(on: clip) {} }
                            .simultaneousGesture(TapGesture(count: 2).onEnded { act(on: clip, onSubmit) })
                            .contextMenu { rowMenu(for: clip) }
                            // Drag a clip into another app: text as text, a picture as a PNG.
                            .onDrag { ClipDragItem.provider(for: clip, imageData: imageData) }
                            // Reaching the last row by scrolling loads the next page. `loadMore` is a no-op once the
                            // history is exhausted and appends synchronously, so it cannot loop: the appended rows
                            // push this row off the end and only the new last row triggers again.
                            .onAppear { if clip.id == model.clips.last?.id { model.loadMore() } }
                    }
                }
                .padding(PanelMetrics.contentInset)
            }
            .panelScrollEdges()
            .onChange(of: model.selectedIndex) {
                if let id = model.selectedClip?.id { proxy.scrollTo(id) }
            }
            // Focus stays in the search field, so VoiceOver would not notice the selection moving: say it.
            // Keyed on the clip, not the index, so a new query that puts a different clip first is announced too.
            // `onChange` does not fire for the initial value, so opening the panel stays quiet.
            .onChange(of: model.selectedClip?.id) {
                guard let clip = model.selectedClip else { return }
                AccessibilityNotification.Announcement(ClipRow.accessibilityLabel(for: clip, imageData: imageData)).post()
            }
        }
    }
}
