import Foundation
import SQLite3
import Testing
@testable import PastuCore

@Suite struct ClipStoreRichTextTests {
    private let rtf = Data("{\\rtf1 hello}".utf8)
    private let html = Data("<b>hello</b>".utf8)

    private func clip(_ text: String, rtf: Data? = nil, html: Data? = nil, at seconds: TimeInterval = 1) -> CapturedClip {
        CapturedClip(
            text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: seconds), rtf: rtf, html: html
        )
    }

    @Test func formattingIsStoredAndMarkedOnTheClip() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("hello", rtf: rtf, html: html))
        let stored = try #require(try store.recent().first)
        #expect(stored.hasFormatting)
        let rich = try #require(try store.richContent(id: id))
        #expect(rich.rtf == rtf)
        #expect(rich.html == html)
    }

    @Test func eitherFormatAloneCounts() throws {
        let store = try ClipStore()
        let onlyRTF = try store.insert(clip("a", rtf: rtf))
        let onlyHTML = try store.insert(clip("b", html: html))
        #expect(try store.richContent(id: onlyRTF) == RichContent(rtf: rtf, html: nil))
        #expect(try store.richContent(id: onlyHTML) == RichContent(rtf: nil, html: html))
        #expect(try store.recent().allSatisfy(\.hasFormatting))
    }

    @Test func plainClipsHaveNoFormatting() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("plain"))
        #expect(try store.recent().first?.hasFormatting == false)
        #expect(try store.richContent(id: id) == nil)
        #expect(try store.richContent(id: 9_999) == nil)
    }

    @Test func copyingTheSameTextAgainWithoutFormattingKeepsTheFormatting() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("hello", rtf: rtf, html: html, at: 1))
        try store.insert(clip("hello", at: 2))
        #expect(try store.recent().count == 1)
        #expect(try store.richContent(id: id)?.rtf == rtf)
    }

    @Test func copyingTheSameTextAgainWithNewFormattingReplacesIt() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("hello", rtf: rtf, at: 1))
        let newer = Data("{\\rtf1 \\b hello}".utf8)
        try store.insert(clip("hello", rtf: newer, at: 2))
        #expect(try store.richContent(id: id)?.rtf == newer)
    }

    @Test func formattingCountsTowardsTheEstimatedSize() throws {
        let store = try ClipStore()
        let before = try store.estimatedSizeInBytes()
        try store.insert(clip("hello", rtf: Data(repeating: 1, count: 1_000), html: Data(repeating: 2, count: 500)))
        let plainOnly = Int(Double(5) * ClipStore.indexOverheadFactor)
        #expect(try store.estimatedSizeInBytes() - before == plainOnly + 1_500)
    }

    @Test func aDatabaseFromBeforeFormattingIsUpgraded() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("old.db").path

        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        sqlite3_exec(db, """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, source_bundle_id TEXT,
                first_copied_at REAL NOT NULL, last_copied_at REAL NOT NULL, copy_count INTEGER NOT NULL DEFAULT 1,
                pinned INTEGER NOT NULL DEFAULT 0, kind TEXT NOT NULL DEFAULT 'text', image BLOB, ocr_text TEXT
            );
            INSERT INTO clips (text, first_copied_at, last_copied_at) VALUES ('old clip', 1, 1);
            PRAGMA user_version = 4;
            """, nil, nil, nil)
        sqlite3_close(db)

        let store = try ClipStore(path: path)
        let old = try #require(try store.recent().first)
        #expect(old.text == "old clip")
        #expect(old.hasFormatting == false)
        let id = try store.insert(clip("new", rtf: rtf))
        #expect(try store.richContent(id: id)?.rtf == rtf)
    }
}
