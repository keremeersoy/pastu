import PastuCore
import SwiftUI

/// The selected clip on a calm rounded surface: its text (or link, or picture) with search matches highlighted and
/// scrolled into view, then a small metadata grid. There is no app/time header because the row already shows it.
struct PreviewPane: View {
    let clip: StoredClip?
    let query: String
    let imageData: (Int64) -> Data?

    /// Code-like text (terminal or editor source, or code signals in the text) is set monospaced; prose uses `.body`.
    /// Only the start of the text is inspected, so this is cheap for any clip.
    static func usesMonospace(for clip: StoredClip) -> Bool {
        clip.kind == .text && ClipFormatting.looksLikeCode(clip.text, sourceBundleIdentifier: clip.sourceBundleIdentifier)
    }

    var body: some View {
        Group {
            if let clip {
                let content = PreviewContent.cached(for: clip, query: query)
                VStack(alignment: .leading, spacing: 12) {
                    switch content.body {
                    case .picture: picturePreview(for: clip)
                    case let .link(host, full): linkPreview(host: host, full: full)
                    case let .text(head, tail): textPreview(head: head, tail: tail, content: content, clip: clip)
                    }
                    MetadataGrid(clip: clip, size: size(of: clip, content: content))
                }
            } else {
                Text("Select a clip to preview")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(surface, in: RoundedRectangle(cornerRadius: PanelMetrics.innerRadius, style: .continuous))
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// The text sits on its own calm surface, not on the glass, so long clips stay readable. On the opaque Reduce
    /// Transparency shell the window background would be invisible, so a light fill keeps the areas apart there.
    private var surface: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.background.opacity(0.55))
    }

    // MARK: Kinds

    private func textPreview(head: AttributedString?, tail: AttributedString, content: PreviewContent, clip: StoredClip) -> some View {
        let font: Font = content.usesMonospace ? .system(.body, design: .monospaced) : .body
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id(PreviewAnchor.top)
                    if content.hiddenBefore > 0 {
                        marker("… \(content.hiddenBefore) earlier characters").padding(.bottom, 6)
                    }
                    // Two pieces so the scroll view has an anchor at the line holding the first match.
                    if let head { Text(head) }
                    Text(tail).id(PreviewAnchor.match)
                    if content.hiddenAfter > 0 {
                        marker("… \(content.hiddenAfter) more characters").padding(.top, 6)
                    }
                }
                .font(font)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear { scroll(proxy, content: content) }
            .onChange(of: PreviewContent.Key(clip: clip, query: query)) { scroll(proxy, content: content) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, content: PreviewContent) {
        proxy.scrollTo(content.scrollsToMatch ? PreviewAnchor.match : PreviewAnchor.top, anchor: .top)
    }

    private func marker(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Host as the heading, the full address below. Nothing is fetched, ever.
    private func linkPreview(host: String, full: AttributedString) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(host)
                .font(.title3.weight(.semibold))
            Text(full)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func picturePreview(for clip: StoredClip) -> some View {
        if let image = ImageCache.shared.fullImage(for: clip.id, load: imageData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Label("Picture not available", systemImage: "photo")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func size(of clip: StoredClip, content: PreviewContent) -> String {
        guard clip.kind == .image else { return content.textStats }
        let picture = ImageCache.shared.info(for: clip.id, load: imageData)
        return picture.map { "\($0.width)×\($0.height) · \(ClipFormatting.fileSize($0.byteCount))" } ?? "Image"
    }
}

private enum PreviewAnchor: Hashable {
    case top, match
}

/// Source, Copied, Size, and when they apply, how often it was copied and that it is pinned.
private struct MetadataGrid: View {
    let clip: StoredClip
    let size: String

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 3) {
            row("Source", AppLookup.name(for: clip.sourceBundleIdentifier) ?? "Unknown app")
            row("Copied", ClipFormatting.relativeTime(from: clip.lastCopiedAt, to: Date()))
            row("Size", size)
            if clip.copyCount > 1 { row("Times copied", "\(clip.copyCount)") }
            if clip.isPinned { row("Pinned", "Yes") }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text(value).lineLimit(1).truncationMode(.middle)
        }
    }
}

/// Everything the preview derives from a clip's text for one query. A clip can be 1 MB, so this is built once per
/// clip and query (see `cached(for:query:)`), never in a view body, and only the shown window is styled or inspected.
struct PreviewContent {
    enum Body {
        case picture
        case link(host: String, full: AttributedString)
        /// `tail` starts at the line holding the first match; `head` is the text before it (nil when there is none).
        case text(head: AttributedString?, tail: AttributedString)
    }

    struct Key: Hashable {
        let id: Int64
        let query: String
        /// Guards against a reused id with different text; O(1) for native strings.
        let length: Int

        init(clip: StoredClip, query: String) {
            id = clip.id
            self.query = query
            length = clip.text.utf8.count
        }
    }

    let body: Body
    let usesMonospace: Bool
    let hiddenBefore: Int
    let hiddenAfter: Int
    /// Whether a match sits below the top, so the preview should scroll to it.
    let scrollsToMatch: Bool
    /// "57 characters · 2 lines" for the whole clip, not just the shown window.
    let textStats: String

    /// How many contents were actually built; lets tests prove the cache is used.
    @MainActor private(set) static var computations = 0
    @MainActor private static var cache: [(key: Key, content: PreviewContent)] = []
    /// A few entries are enough: the selected clip, and the ones just before it while moving through the list.
    private static let cacheLimit = 8

    @MainActor
    static func cached(for clip: StoredClip, query: String) -> PreviewContent {
        let key = Key(clip: clip, query: query)
        if let hit = cache.firstIndex(where: { $0.key == key }) { return cache[hit].content }
        computations += 1
        let content = PreviewContent(clip: clip, query: query)
        cache.insert((key, content), at: 0)
        if cache.count > cacheLimit { cache.removeLast() }
        return content
    }

    private static let matchBackground = Color.accentColor.opacity(0.22)

    init(clip: StoredClip, query: String) {
        if clip.kind == .image {
            self.init(body: .picture, monospace: false, before: 0, after: 0, scrolls: false, stats: "")
            return
        }
        let stats = ClipFormatting.stats(clip.text)
        if clip.kind == .link, let link = ClipFormatting.linkParts(clip.text) {
            let ranges = SearchHighlighter.ranges(of: query, in: link.full)
            let full = MatchHighlight.attributed(link.full, ranges: ranges, font: .body, background: Self.matchBackground)
            self.init(body: .link(host: link.host, full: full), monospace: false, before: 0, after: 0, scrolls: false, stats: stats)
            return
        }

        let preview = ClipFormatting.previewText(clip.text, around: query)
        let shown = preview.text
        let monospace = ClipFormatting.looksLikeCode(shown, sourceBundleIdentifier: clip.sourceBundleIdentifier)
        let font: Font = monospace ? .system(.body, design: .monospaced) : .body
        let ranges = SearchHighlighter.ranges(of: query, in: shown)
        let attributed = MatchHighlight.attributed(shown, ranges: ranges, font: font, background: Self.matchBackground)

        var head: AttributedString?
        var tail = attributed
        if let first = ranges.first, let split = Self.anchorSplit(in: shown, firstMatch: first.lowerBound),
           let headRange = Range(shown.startIndex..<split.headEnd, in: attributed),
           let tailRange = Range(split.tailStart..<shown.endIndex, in: attributed) {
            head = AttributedString(attributed[headRange])
            tail = AttributedString(attributed[tailRange])
        }
        self.init(
            body: .text(head: head, tail: tail), monospace: monospace,
            before: preview.hiddenBefore, after: preview.hiddenAfter, scrolls: head != nil, stats: stats
        )
    }

    private init(body: Body, monospace: Bool, before: Int, after: Int, scrolls: Bool, stats: String) {
        self.body = body
        usesMonospace = monospace
        hiddenBefore = before
        hiddenAfter = after
        scrollsToMatch = scrolls
        textStats = stats
    }

    /// Where to cut the shown text so the second piece starts at the first match's line: `headEnd` drops the line
    /// break between the pieces (the two `Text`s stack anyway). A very long line is cut at a space a little before
    /// the match instead, so the match still lands in view. Nil when the match is already near the top.
    static func anchorSplit(in text: String, firstMatch: String.Index) -> (headEnd: String.Index, tailStart: String.Index)? {
        let lineStart = text[..<firstMatch].lastIndex(where: \.isNewline).map { text.index(after: $0) } ?? text.startIndex
        if text.distance(from: lineStart, to: firstMatch) <= 240 {
            guard lineStart > text.startIndex else { return nil }
            return (text.index(before: lineStart), lineStart)
        }
        let near = text.index(firstMatch, offsetBy: -120)
        guard let space = text[lineStart..<near].lastIndex(where: { $0 == " " }) else { return nil }
        return (space, text.index(after: space))
    }
}
