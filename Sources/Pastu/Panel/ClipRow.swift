import PastuCore
import SwiftUI

/// One row of the clip list: leading icon or thumbnail, a one-line title and a subtitle that is either
/// "App · time" or, when the search matched outside the visible title, a snippet around the match.
/// VoiceOver sees the row as a single element because keyboard focus never leaves the search field.
struct ClipRow: View {
    let clip: StoredClip
    let isSelected: Bool
    let shortcutDigit: Int?
    /// The ⌘ badge is shown on the selected row, and on every row while ⌘ is held.
    let showsShortcut: Bool
    let query: String
    /// Shown instead of "App · time"; computed once per clip and query by `ClipListModel.rowSnippet(for:)`,
    /// because finding it scans the whole clip and row bodies are rebuilt on every hover and key press.
    let snippet: SearchHighlighter.Snippet?
    let imageData: (Int64) -> Data?
    @State private var isHovered: Bool

    /// - Parameter isHovered: the initial hover state; lets snapshot tests render a hovered row without a mouse.
    init(
        clip: StoredClip, isSelected: Bool, shortcutDigit: Int?, showsShortcut: Bool, query: String,
        snippet: SearchHighlighter.Snippet?, imageData: @escaping (Int64) -> Data?, isHovered: Bool = false
    ) {
        self.clip = clip
        self.isSelected = isSelected
        self.shortcutDigit = shortcutDigit
        self.showsShortcut = showsShortcut
        self.query = query
        self.snippet = snippet
        self.imageData = imageData
        _isHovered = State(initialValue: isHovered)
    }

    var body: some View {
        let picture = clip.kind == .image ? ImageCache.shared.info(for: clip.id, load: imageData) : nil
        let title = title
        HStack(spacing: 8) {
            Group {
                if clip.kind == .image {
                    ThumbnailView(info: picture, isOnAccent: isSelected)
                } else {
                    AppIconView(bundleIdentifier: clip.sourceBundleIdentifier, size: 24, isOnAccent: isSelected)
                }
            }
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(highlighted(title, ranges: titleRanges(title), font: .body))
                    .font(.body)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    if clip.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    subtitle(picture)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsShortcut, let shortcutDigit {
                ShortcutBadge(digit: shortcutDigit, isOnAccent: isSelected)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: clip, picture: picture))
        // The label says what and where from; the value carries the text itself, as a list cell's would.
        .accessibilityValue(clip.kind == .image ? "" : title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Press Return to paste")
    }

    // MARK: Text

    private var title: String {
        clip.kind == .image ? "Image" : ClipFormatting.rowTitle(clip.text)
    }

    private func titleRanges(_ title: String) -> [Range<String.Index>] {
        guard clip.kind != .image, !query.isEmpty else { return [] }
        return SearchHighlighter.ranges(of: query, in: title)
    }

    @ViewBuilder
    private func subtitle(_ picture: ImageCache.Info?) -> some View {
        if let snippet {
            Text(highlighted(snippet.text, ranges: snippet.highlights, font: .subheadline))
        } else {
            let time = ClipFormatting.relativeTime(from: clip.lastCopiedAt, to: Date())
            let size = picture.map { "\($0.width)×\($0.height)" }
            Text([AppLookup.name(for: clip.sourceBundleIdentifier), size, time].compactMap { $0 }.joined(separator: " · "))
        }
    }

    /// Matches in semibold. On the accent fill they are also underlined and full white, because a colored
    /// background behind the match would fight the selection color.
    private func highlighted(_ text: String, ranges: [Range<String.Index>], font: Font) -> AttributedString {
        var attributed = AttributedString(text)
        for range in ranges {
            // Short-term ranges may end inside a grapheme; skip anything that does not map rather than trap.
            guard let target = Range(range, in: attributed) else { continue }
            attributed[target].font = font.weight(.semibold)
            if isSelected {
                attributed[target].foregroundColor = .white
                attributed[target].underlineStyle = .single
            } else {
                attributed[target].foregroundColor = .primary
            }
        }
        return attributed
    }

    // MARK: Background

    private var background: some View {
        let fill: AnyShapeStyle = if isSelected {
            AnyShapeStyle(Color.accentColor)
        } else if isHovered {
            AnyShapeStyle(.quaternary)
        } else {
            AnyShapeStyle(Color.clear)
        }
        return RoundedRectangle(cornerRadius: PanelMetrics.innerRadius, style: .continuous).fill(fill)
    }

    // MARK: VoiceOver

    /// The row's spoken label; also announced by the panel when the selection moves to this clip.
    static func accessibilityLabel(for clip: StoredClip, imageData: (Int64) -> Data?) -> String {
        let picture = clip.kind == .image ? ImageCache.shared.info(for: clip.id, load: imageData) : nil
        return accessibilityLabel(for: clip, picture: picture)
    }

    private static func accessibilityLabel(for clip: StoredClip, picture: ImageCache.Info?) -> String {
        ClipFormatting.accessibilityLabel(
            kind: clip.kind, appName: AppLookup.name(for: clip.sourceBundleIdentifier),
            pixelSize: picture.map { ($0.width, $0.height) },
            copiedAt: clip.lastCopiedAt, now: Date(), isPinned: clip.isPinned
        )
    }
}

/// A small keycap such as "⌘3".
private struct ShortcutBadge: View {
    let digit: Int
    let isOnAccent: Bool

    var body: some View {
        Text("⌘\(digit)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(isOnAccent ? AnyShapeStyle(.white.opacity(0.9)) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isOnAccent ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(.quaternary))
            )
    }
}
