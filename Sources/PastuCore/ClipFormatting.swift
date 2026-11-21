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
}
