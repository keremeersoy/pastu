import Foundation

/// Finds where a search query matches inside a text, using the same rules as `ClipStore.search`,
/// so the panel highlights exactly what the search matched. Ranges always index into the string
/// they were computed for (title, snippet or preview text).
public enum SearchHighlighter {
    /// A short excerpt of a clip around its first match, ready to show in a list row.
    public struct Snippet: Equatable {
        /// Already contains "…" at a cut end.
        public let text: String
        /// Match ranges, indexing into `text`.
        public let highlights: [Range<String.Index>]
    }

    /// Whitespace-split, same as `ClipStore.search`.
    public static func terms(of query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Every match of every term, sorted, with overlapping or touching ranges merged.
    public static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for term in terms(of: query) {
            var from = text.startIndex
            while let range = firstMatch(of: term, in: text, from: from) {
                found.append(range)
                from = range.upperBound
            }
        }
        return merge(found)
    }

    /// An excerpt of about `maxLength` characters centered (a third before) on the first match.
    /// Nil for an empty query or no match. Whitespace runs collapse to one space, like `rowTitle`.
    /// Only the cut window is processed, so a huge clip stays fast.
    public static func snippet(of query: String, in text: String, maxLength: Int = 120) -> Snippet? {
        guard let match = earliestMatch(of: terms(of: query), in: text) else { return nil }
        let before = text.index(match.lowerBound, offsetBy: -(maxLength / 3), limitedBy: text.startIndex) ?? text.startIndex
        var end = text.index(before, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex
        if end < match.upperBound { end = match.upperBound }

        var body = ""
        var pendingSpace = false
        for character in text[before..<end] {
            if character.isWhitespace {
                pendingSpace = !body.isEmpty
                continue
            }
            if pendingSpace { body.append(" "); pendingSpace = false }
            body.append(character)
        }
        let result = (before > text.startIndex ? "…" : "") + body + (end < text.endIndex ? "…" : "")
        return Snippet(text: result, highlights: ranges(of: query, in: result))
    }

    /// Whether a row title contains any match, so the row can skip the snippet line.
    public static func titleContainsMatch(_ title: String, query: String) -> Bool {
        earliestMatch(of: terms(of: query), in: title) != nil
    }

    /// The match that starts first among all terms; nil without terms or matches.
    static func earliestMatch(of terms: [String], in text: String) -> Range<String.Index>? {
        terms.compactMap { firstMatch(of: $0, in: text, from: text.startIndex) }.min { $0.lowerBound < $1.lowerBound }
    }

    /// First match of one term at or after `from`. Terms of 3+ characters ignore case and accents (the
    /// trigram index); shorter ones fold ASCII letters only, like SQLite's `instr(lower(...))`.
    static func firstMatch(of term: String, in text: String, from: String.Index) -> Range<String.Index>? {
        guard !term.isEmpty, from < text.endIndex else { return nil }
        if term.count >= 3 {
            return text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex)
        }
        return asciiFoldedMatch(of: term, in: text, from: from)
    }

    private static func asciiFoldedMatch(of term: String, in text: String, from: String.Index) -> Range<String.Index>? {
        func fold(_ byte: UInt8) -> UInt8 { (65...90).contains(byte) ? byte + 32 : byte }
        let needle = term.utf8.map(fold)
        let utf8 = text.utf8
        var start = from
        // UTF-8 is self-synchronizing, so a byte match always starts on a scalar boundary.
        while start < utf8.endIndex {
            var cursor = start
            var matched = 0
            while matched < needle.count, cursor < utf8.endIndex, fold(utf8[cursor]) == needle[matched] {
                cursor = utf8.index(after: cursor)
                matched += 1
            }
            if matched == needle.count { return start..<cursor }
            start = utf8.index(after: start)
        }
        return nil
    }

    private static func merge(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        var merged: [Range<String.Index>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
