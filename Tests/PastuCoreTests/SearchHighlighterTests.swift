import Foundation
import Testing
@testable import PastuCore

@Suite struct SearchHighlighterTests {
    private func covered(_ ranges: [Range<String.Index>], in text: String) -> [String] {
        ranges.map { String(text[$0]) }
    }

    @Test func rangesAreCaseAndAccentInsensitiveForLongTerms() {
        let text = "Café au lait"
        #expect(covered(SearchHighlighter.ranges(of: "cafe", in: text), in: text) == ["Café"])
    }

    @Test func shortTermsFoldAsciiCaseOnly() {
        #expect(SearchHighlighter.ranges(of: "is", in: "This IS").count == 2)
        #expect(SearchHighlighter.ranges(of: "is", in: "İstanbul").isEmpty)
    }

    @Test func multipleTermsMergeOverlaps() {
        let text = "abcd"
        #expect(covered(SearchHighlighter.ranges(of: "abc bcd", in: text), in: text) == ["abcd"])
    }

    @Test func emptyQueryHasNoRangesOrSnippet() {
        #expect(SearchHighlighter.ranges(of: "   ", in: "anything").isEmpty)
        #expect(SearchHighlighter.snippet(of: "   ", in: "anything") == nil)
    }

    @Test func snippetCentersOnFirstMatch() throws {
        let text = String(repeating: "x ", count: 500) + "needle" + String(repeating: " y", count: 500)
        let snippet = try #require(SearchHighlighter.snippet(of: "needle", in: text))
        #expect(snippet.text.hasPrefix("…") && snippet.text.hasSuffix("…"))
        #expect(snippet.text.contains("needle"))
        #expect(snippet.text.count <= 122)
        #expect(covered(snippet.highlights, in: snippet.text) == ["needle"])
    }

    @Test func snippetAtStartHasNoLeadingEllipsis() throws {
        let snippet = try #require(SearchHighlighter.snippet(of: "hello", in: "hello   world\n\nagain " + String(repeating: "z", count: 500)))
        #expect(!snippet.text.hasPrefix("…"))
        #expect(snippet.text.hasPrefix("hello world again"))
        #expect(snippet.text.hasSuffix("…"))
    }

    @Test func snippetNoMatchIsNil() {
        #expect(SearchHighlighter.snippet(of: "zzz", in: "hello world") == nil)
    }

    @Test func snippetFindsMatchNearEndOfHugeText() throws {
        let text = String(repeating: "a", count: 1_000_000) + " needle"
        let snippet = try #require(SearchHighlighter.snippet(of: "needle", in: text))
        #expect(snippet.text.contains("needle"))
    }

    @Test func snippetNeverSplitsEmojiOrCombiningMarks() throws {
        let filler = String(repeating: "👩‍👩‍👧e\u{301}", count: 200)
        let text = filler + " needle " + filler
        let snippet = try #require(SearchHighlighter.snippet(of: "needle", in: text))
        let source = Set(text)
        for character in snippet.text where character != "…" {
            #expect(source.contains(character))
        }
    }

    @Test func titleContainsMatchReportsHits() {
        #expect(SearchHighlighter.titleContainsMatch("Hello World", query: "world"))
        #expect(!SearchHighlighter.titleContainsMatch("Hello World", query: "moon"))
        #expect(!SearchHighlighter.titleContainsMatch("Hello World", query: " "))
    }
}
