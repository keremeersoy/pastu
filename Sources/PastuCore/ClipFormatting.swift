import Foundation

/// Pure text helpers for the panel: row titles, preview text, relative time, stats.
public enum ClipFormatting {
    /// One-line title for a list row. Only looks at the start of the text, so a huge clip
    /// never makes the list slow.
    public static func rowTitle(_ text: String, maxLength: Int = 200) -> String {
        let head = text.drop(while: \.isWhitespace).prefix(maxLength * 4)
        var title = ""
        var pendingSpace = false
        for character in head {
            if character.isWhitespace {
                pendingSpace = !title.isEmpty
                continue
            }
            if pendingSpace { title.append(" "); pendingSpace = false }
            title.append(character)
        }
        guard title.count > maxLength else { return title }
        return String(title.prefix(maxLength)) + "…"
    }

    /// The start of the text for the preview pane, plus how many characters were cut off.
    public static func previewText(_ text: String, limit: Int = 4_000) -> (text: String, hiddenCharacters: Int) {
        let shown = String(text.prefix(limit))
        return (shown, max(text.count - shown.count, 0))
    }

    /// Like `previewText(_:limit:)`, but when the first search match lies beyond the first `limit` characters
    /// the preview is a `limit`-sized window around it, so the highlighted match is actually visible.
    /// Otherwise (match inside the start, or no match) it equals the start-of-text preview.
    public static func previewText(
        _ text: String, around query: String, limit: Int = 4_000
    ) -> (text: String, hiddenBefore: Int, hiddenAfter: Int) {
        let head = previewText(text, limit: limit)
        let terms = SearchHighlighter.terms(of: query)
        guard let match = SearchHighlighter.earliestMatch(of: terms, in: text),
              let limitIndex = text.index(text.startIndex, offsetBy: limit, limitedBy: text.endIndex),
              match.lowerBound >= limitIndex
        else { return (head.text, 0, head.hiddenCharacters) }

        let start = text.index(match.lowerBound, offsetBy: -(limit / 3), limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(start, offsetBy: limit, limitedBy: text.endIndex) ?? text.endIndex
        return (String(text[start..<end]),
                text.distance(from: text.startIndex, to: start),
                text.distance(from: end, to: text.endIndex))
    }

    /// Short, locale-independent relative time ("just now", "5m ago", "2h ago", "3d ago", "2mo ago").
    public static func relativeTime(from date: Date, to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3_600: return "\(seconds / 60)m ago"
        case ..<86_400: return "\(seconds / 3_600)h ago"
        case ..<(30 * 86_400): return "\(seconds / 86_400)d ago"
        default: return "\(seconds / (30 * 86_400))mo ago"
        }
    }

    /// "123 characters · 4 lines".
    public static func stats(_ text: String) -> String {
        let characters = text.count
        var lines = text.reduce(into: 1) { count, character in if character.isNewline { count += 1 } }
        if text.last?.isNewline == true, lines > 1 { lines -= 1 }
        return "\(characters) character\(characters == 1 ? "" : "s") · \(lines) line\(lines == 1 ? "" : "s")"
    }

    /// "512 B", "1.5 KB", "48 KB", "2.3 MB": one decimal below 10, none above. Locale-independent.
    public static func fileSize(_ bytes: Int) -> String {
        let kilobyte = 1024.0, megabyte = 1024.0 * 1024.0
        let size = Double(max(bytes, 0))
        if size < kilobyte { return "\(Int(size)) B" }
        if size < megabyte {
            let value = size / kilobyte
            return String(format: value < 10 ? "%.1f KB" : "%.0f KB", value)
        }
        let value = size / megabyte
        return String(format: value < 10 ? "%.1f MB" : "%.0f MB", value)
    }
}
