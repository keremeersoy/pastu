import Foundation
import Testing
@testable import PastuCore

@Suite struct ClipFormattingTests {
    // MARK: rowTitle

    @Test func rowTitleCollapsesWhitespaceAndNewlines() {
        #expect(ClipFormatting.rowTitle("  hello\n\n  world\t!  ") == "hello world !")
    }

    @Test func rowTitleTruncatesWithEllipsis() {
        let title = ClipFormatting.rowTitle(String(repeating: "a", count: 300), maxLength: 10)
        #expect(title == String(repeating: "a", count: 10) + "…")
    }

    @Test func rowTitleLeavesShortTextAlone() {
        #expect(ClipFormatting.rowTitle("short", maxLength: 10) == "short")
    }

    @Test func rowTitleOfHugeTextStaysSmall() {
        let title = ClipFormatting.rowTitle(String(repeating: "word ", count: 400_000), maxLength: 200)
        #expect(title.count == 201)
    }

    @Test func rowTitleSkipsLongLeadingWhitespace() {
        let text = String(repeating: "\n", count: 5_000) + "actual content"
        #expect(ClipFormatting.rowTitle(text) == "actual content")
    }

    // MARK: previewText

    @Test func previewShowsEverythingWhenShort() {
        let preview = ClipFormatting.previewText("line1\nline2", limit: 100)
        #expect(preview.text == "line1\nline2")
        #expect(preview.hiddenCharacters == 0)
    }

    @Test func previewCutsAtLimitAndReportsHiddenCount() {
        let preview = ClipFormatting.previewText(String(repeating: "a", count: 25), limit: 10)
        #expect(preview.text == String(repeating: "a", count: 10))
        #expect(preview.hiddenCharacters == 15)
    }

    // MARK: relativeTime

    @Test(arguments: [
        (0.0, "just now"), (59.0, "just now"),
        (60.0, "1m ago"), (3_599.0, "59m ago"),
        (3_600.0, "1h ago"), (86_399.0, "23h ago"),
        (86_400.0, "1d ago"), (29.0 * 86_400, "29d ago"),
        (30.0 * 86_400, "1mo ago"), (95.0 * 86_400, "3mo ago"),
    ])
    func relativeTimeBuckets(secondsAgo: Double, expected: String) {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        #expect(ClipFormatting.relativeTime(from: now.addingTimeInterval(-secondsAgo), to: now) == expected)
    }

    @Test func relativeTimeTreatsFutureDatesAsJustNow() {
        let now = Date(timeIntervalSince1970: 1_000_000_000)
        #expect(ClipFormatting.relativeTime(from: now.addingTimeInterval(500), to: now) == "just now")
    }

    // MARK: stats

    @Test func statsCountCharactersAndLines() {
        #expect(ClipFormatting.stats("ab\ncd\nef") == "8 characters · 3 lines")
    }

    @Test func statsUseSingularForms() {
        #expect(ClipFormatting.stats("x") == "1 character · 1 line")
    }

    @Test func statsDoNotCountATrailingNewlineAsALine() {
        #expect(ClipFormatting.stats("one\ntwo\n") == "8 characters · 2 lines")
    }
}
