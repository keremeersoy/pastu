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

    // An explicitly typed constant: as an inline literal, Swift 6.3 (Xcode 26 on CI) gives up type-checking it.
    static let relativeTimeCases: [(Double, String)] = [
        (0.0, "just now"), (59.0, "just now"),
        (60.0, "1m ago"), (3_599.0, "59m ago"),
        (3_600.0, "1h ago"), (86_399.0, "23h ago"),
        (86_400.0, "1d ago"), (29.0 * 86_400, "29d ago"),
        (30.0 * 86_400, "1mo ago"), (95.0 * 86_400, "3mo ago"),
    ]

    @Test(arguments: relativeTimeCases)
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

@Suite struct FileSizeFormattingTests {
    private let kb = 1024
    private let mb = 1024 * 1024

    @Test func smallSizesAreShownInBytes() {
        #expect(ClipFormatting.fileSize(0) == "0 B")
        #expect(ClipFormatting.fileSize(512) == "512 B")
        #expect(ClipFormatting.fileSize(1023) == "1023 B")
    }

    @Test func kilobytesHaveOneDecimalBelowTenAndNoneAbove() {
        #expect(ClipFormatting.fileSize(kb) == "1.0 KB")
        #expect(ClipFormatting.fileSize(kb + kb / 2) == "1.5 KB")
        #expect(ClipFormatting.fileSize(10 * kb) == "10 KB")
        #expect(ClipFormatting.fileSize(48 * kb) == "48 KB")
    }

    @Test func megabytesFollowTheSameRule() {
        #expect(ClipFormatting.fileSize(mb) == "1.0 MB")
        #expect(ClipFormatting.fileSize(2 * mb + 300 * kb) == "2.3 MB")
        #expect(ClipFormatting.fileSize(10 * mb) == "10 MB")
    }

    @Test func justBelowAMegabyteStaysInKilobytes() {
        #expect(ClipFormatting.fileSize(mb - 1) == "1024 KB")
    }

    // MARK: previewText around a match

    @Test func previewAroundMatchBeyondLimit() {
        let text = String(repeating: "a", count: 10_000) + "needle" + String(repeating: "b", count: 10)
        let preview = ClipFormatting.previewText(text, around: "needle", limit: 4_000)
        #expect(preview.text.contains("needle"))
        #expect(preview.hiddenBefore > 0)
        #expect(preview.text.count <= 4_000)
        #expect(preview.hiddenBefore + preview.text.count + preview.hiddenAfter == text.count)
    }

    @Test func previewAroundMatchInsideLimitMatchesPlainPreview() {
        let text = "hello needle " + String(repeating: "a", count: 10_000)
        let preview = ClipFormatting.previewText(text, around: "needle", limit: 4_000)
        let plain = ClipFormatting.previewText(text, limit: 4_000)
        #expect(preview.hiddenBefore == 0)
        #expect(preview.text == plain.text)
        #expect(preview.hiddenAfter == plain.hiddenCharacters)
    }

    @Test func previewAroundMissingMatchIsPlainPreview() {
        let text = String(repeating: "a", count: 5_000)
        let preview = ClipFormatting.previewText(text, around: "zzz", limit: 100)
        #expect(preview.hiddenBefore == 0 && preview.text.count == 100 && preview.hiddenAfter == 4_900)
    }

    // MARK: looksLikeCode

    @Test func looksLikeCodeForCodeEditorSources() {
        for id in ["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty",
                   "dev.warp.Warp-Stable", "com.apple.dt.Xcode", "com.microsoft.VSCode", "dev.zed.Zed"] {
            #expect(ClipFormatting.looksLikeCode("anything", sourceBundleIdentifier: id))
        }
        #expect(!ClipFormatting.looksLikeCode("anything", sourceBundleIdentifier: "com.apple.Safari"))
    }

    @Test func looksLikeCodeIsFalseForProse() {
        #expect(!ClipFormatting.looksLikeCode("Hi; see you at 5.\nThanks", sourceBundleIdentifier: nil))
    }

    @Test func looksLikeCodeForShellSnippet() {
        #expect(ClipFormatting.looksLikeCode("$ swift test\n$ git push", sourceBundleIdentifier: nil))
    }

    @Test func looksLikeCodeForBracesAndSemicolons() {
        let code = "func f() {\n    return 1;\n}"
        #expect(ClipFormatting.looksLikeCode(code, sourceBundleIdentifier: nil))
    }

    @Test func looksLikeCodeNeedsTwoLines() {
        #expect(!ClipFormatting.looksLikeCode("$ swift test", sourceBundleIdentifier: nil))
    }

    // MARK: linkParts

    @Test func linkPartsForUrlAndMailto() {
        let url = ClipFormatting.linkParts("https://example.com/a/b?q=1")
        #expect(url?.host == "example.com")
        #expect(url?.full == "https://example.com/a/b?q=1")
        let mail = ClipFormatting.linkParts("mailto:me@example.com")
        #expect(mail?.host == "me@example.com")
        #expect(mail?.full == "mailto:me@example.com")
    }

    @Test func linkPartsNilForPlainText() {
        #expect(ClipFormatting.linkParts("just some text") == nil)
    }

    // MARK: accessibilityLabel

    private func label(_ kind: ClipKind, _ app: String?, size: (width: Int, height: Int)? = nil,
                       ago: Double, pinned: Bool = false) -> String {
        let now = Date(timeIntervalSince1970: 10_000_000)
        return ClipFormatting.accessibilityLabel(kind: kind, appName: app, pixelSize: size,
                                                 copiedAt: now.addingTimeInterval(-ago), now: now, isPinned: pinned)
    }

    @Test func accessibilityLabelForms() {
        #expect(label(.text, "Terminal", ago: 5, pinned: true) == "Text from Terminal, just now, pinned")
        #expect(label(.link, "Safari", ago: 300) == "Link from Safari, 5 minutes ago")
        #expect(label(.image, "Preview", size: (1440, 900), ago: 7_200) == "Image from Preview, 1440 by 900, 2 hours ago")
        #expect(label(.text, nil, ago: 3 * 86_400) == "Text, 3 days ago")
    }

    @Test func accessibilityLabelSpokenTimeBuckets() {
        #expect(label(.text, nil, ago: 60) == "Text, 1 minute ago")
        #expect(label(.text, nil, ago: 3_600) == "Text, 1 hour ago")
        #expect(label(.text, nil, ago: 86_400) == "Text, 1 day ago")
        #expect(label(.text, nil, ago: 30 * 86_400) == "Text, 1 month ago")
        #expect(label(.text, nil, ago: 90 * 86_400) == "Text, 3 months ago")
    }
}
