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
                HStack(spacing: 0) {
                    list.frame(width: PanelMetrics.listWidth)
                    Divider()
                    PreviewPane(clip: model.selectedClip)
                }
            }

            Divider()
            HintFooter(canAutoPaste: canAutoPaste)
        }
        .frame(width: PanelMetrics.size.width, height: PanelMetrics.size.height)
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
        HStack(spacing: 10) {
            AppIconView(bundleIdentifier: clip.sourceBundleIdentifier, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(ClipFormatting.rowTitle(clip.text))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let shortcutDigit {
                Text("⌘\(shortcutDigit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.35) : .clear)
        )
    }

    private var subtitle: String {
        let time = ClipFormatting.relativeTime(from: clip.lastCopiedAt, to: Date())
        guard let app = AppLookup.name(for: clip.sourceBundleIdentifier) else { return time }
        return "\(app) · \(time)"
    }
}

private struct PreviewPane: View {
    let clip: StoredClip?

    var body: some View {
        if let clip {
            let preview = ClipFormatting.previewText(clip.text)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    AppIconView(bundleIdentifier: clip.sourceBundleIdentifier, size: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(AppLookup.name(for: clip.sourceBundleIdentifier) ?? "Unknown app")
                            .font(.callout.weight(.medium))
                        Text(ClipFormatting.relativeTime(from: clip.lastCopiedAt, to: Date()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ScrollView {
                    Text(preview.text)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if preview.hiddenCharacters > 0 {
                        Text("… \(preview.hiddenCharacters) more characters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
                }

                Text(details(for: clip))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("Select a clip to preview")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func details(for clip: StoredClip) -> String {
        let stats = ClipFormatting.stats(clip.text)
        return clip.copyCount > 1 ? "\(stats) · copied \(clip.copyCount) times" : stats
    }
}

private struct AppIconView: View {
    let bundleIdentifier: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = AppLookup.icon(for: bundleIdentifier) {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "doc.text").resizable().scaledToFit().foregroundStyle(.secondary).padding(3)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct HintFooter: View {
    let canAutoPaste: Bool

    var body: some View {
        HStack(spacing: 16) {
            if canAutoPaste {
                Text("↩ Paste")
            } else {
                // Without the Accessibility permission Pastu can only copy; the user presses ⌘V themselves.
                Label("↩ Copies only: enable Accessibility to auto-paste", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Text("⌘1–9 Quick paste")
            Text("↑↓ Select")
            Text("esc Close")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
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
