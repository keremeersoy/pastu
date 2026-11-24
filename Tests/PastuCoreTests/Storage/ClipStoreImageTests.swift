import Foundation
import SQLite3
import Testing
@testable import PastuCore

@Suite struct ClipStoreImageTests {
    private func pngBytes(_ seed: UInt8, count: Int = 100) -> Data { Data(repeating: seed, count: count) }

    private func textClip(_ text: String, at seconds: TimeInterval) -> CapturedClip {
        CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: seconds))
    }

    private func imageClip(_ seed: UInt8, at seconds: TimeInterval, count: Int = 100, app: String? = nil) -> CapturedClip {
        .image(png: pngBytes(seed, count: count), sourceBundleIdentifier: app, date: Date(timeIntervalSince1970: seconds))
    }

    // MARK: CapturedClip.image

    @Test func identicalImagesGetTheSameKeyAndDifferentImagesDoNot() {
        let a1 = imageClip(1, at: 1), a2 = imageClip(1, at: 2), b = imageClip(2, at: 3)
        #expect(a1.text == a2.text)
        #expect(a1.text != b.text)
        #expect(a1.text.hasPrefix("[image] "))
        #expect(a1.imagePNG == pngBytes(1))
    }

    // MARK: Storing

    @Test func imageIsStoredWithItsKindAndBytes() throws {
        let store = try ClipStore()
        let id = try store.insert(imageClip(7, at: 1, app: "com.apple.screencaptureui"))
        let stored = try #require(try store.recent().first)
        #expect(stored.id == id)
        #expect(stored.kind == .image)
        #expect(stored.sourceBundleIdentifier == "com.apple.screencaptureui")
        #expect(try store.imageData(id: id) == pngBytes(7))
    }

    @Test func textClipsHaveNoImageData() throws {
        let store = try ClipStore()
        let id = try store.insert(textClip("hello", at: 1))
        #expect(try store.imageData(id: id) == nil)
        #expect(try store.recent().first?.kind == .text)
    }

    @Test func imageDataForAnUnknownIdIsNil() throws {
        #expect(try ClipStore().imageData(id: 999) == nil)
    }

    @Test func copyingTheSameImageAgainMergesIntoOneRow() throws {
        let store = try ClipStore()
        let first = try store.insert(imageClip(3, at: 1))
        let second = try store.insert(imageClip(3, at: 5))
        let clips = try store.recent()
        #expect(first == second)
        #expect(clips.count == 1)
        #expect(clips.first?.copyCount == 2)
        #expect(try store.imageData(id: first) == pngBytes(3))
    }

    @Test func differentImagesAreSeparateRows() throws {
        let store = try ClipStore()
        try store.insert(imageClip(1, at: 1))
        try store.insert(imageClip(2, at: 2))
        #expect(try store.recent().count == 2)
    }

    @Test func imagesAndTextCoexistNewestFirst() throws {
        let store = try ClipStore()
        try store.insert(textClip("note", at: 1))
        try store.insert(imageClip(1, at: 2))
        #expect(try store.recent().map(\.kind) == [.image, .text])
    }

    // MARK: Type filter

    @Test func imageFilterShowsOnlyImages() throws {
        let store = try ClipStore()
        try store.insert(textClip("note", at: 1))
        try store.insert(textClip("https://swift.org", at: 2))
        try store.insert(imageClip(1, at: 3))
        #expect(try store.recent(kind: .image).map(\.kind) == [.image])
    }

    @Test func textAndLinkFiltersNeverShowImages() throws {
        let store = try ClipStore()
        try store.insert(textClip("note", at: 1))
        try store.insert(textClip("https://swift.org", at: 2))
        try store.insert(imageClip(1, at: 3))
        #expect(try store.recent(kind: .text).map(\.text) == ["note"])
        #expect(try store.recent(kind: .link).map(\.text) == ["https://swift.org"])
    }

    @Test func noFilterShowsEverything() throws {
        let store = try ClipStore()
        try store.insert(textClip("note", at: 1))
        try store.insert(imageClip(1, at: 2))
        #expect(try store.recent().count == 2)
    }

    @Test func searchRespectsTheImageFilter() throws {
        let store = try ClipStore()
        try store.insert(textClip("an image of a cat", at: 1))   // text that merely mentions "image"
        try store.insert(imageClip(1, at: 2))
        #expect(try store.search("image", kind: .image).map(\.kind) == [.image])
        #expect(try store.search("image", kind: .text).map(\.kind) == [.text])
    }

    // MARK: Lifecycle

    @Test func deletingAnImageRemovesItsBytes() throws {
        let store = try ClipStore()
        let id = try store.insert(imageClip(1, at: 1))
        try store.delete(id: id)
        #expect(try store.imageData(id: id) == nil)
        #expect(try store.recent().isEmpty)
        try store.verifyIntegrity()
    }

    @Test func pinningAndClearingTreatImagesLikeAnyClip() throws {
        let store = try ClipStore()
        let keep = try store.insert(imageClip(1, at: 1))
        try store.insert(imageClip(2, at: 2))
        try store.setPinned(id: keep, true)
        try store.clear(keepPinned: true)
        #expect(try store.recent().map(\.id) == [keep])
        #expect(try store.imageData(id: keep) == pngBytes(1))
    }

    // MARK: Size accounting

    @Test func sizeEstimateCountsImageBytesOnceAndTextTimesTheIndexFactor() throws {
        let store = try ClipStore()
        let clip = imageClip(1, at: 1, count: 1_000)
        try store.insert(clip)
        let expected = Int(Double(clip.text.utf8.count) * ClipStore.indexOverheadFactor) + 1_000
        #expect(try store.estimatedSizeInBytes() == expected)
    }

    @Test func sizePruningRemovesTheOldestUnpinnedImagesFirst() throws {
        let store = try ClipStore()
        for seed in 1...3 { try store.insert(imageClip(UInt8(seed), at: Double(seed), count: 1_000)) }
        // Each image costs about 1,000 + a small key, so three exceed 2,500 and the oldest has to go.
        let removed = try store.prune(RetentionPolicy(maxCount: nil, maxAge: nil, maxTotalBytes: 2_500))
        #expect(removed == 1)
        let remaining = try store.recent()
        #expect(remaining.count == 2)
        #expect(try remaining.allSatisfy { try store.imageData(id: $0.id) != nil })
        #expect(remaining.map(\.lastCopiedAt) == [Date(timeIntervalSince1970: 3), Date(timeIntervalSince1970: 2)])
    }

    // MARK: Upgrade from schema v2

    @Test func databaseWithoutImageSupportIsUpgradedAndKeepsItsClips() throws {
        let path = NSTemporaryDirectory() + "pastu-v2-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }

        // Schema as shipped before images (version 2).
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        let v2 = """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, source_bundle_id TEXT,
                first_copied_at REAL NOT NULL, last_copied_at REAL NOT NULL, copy_count INTEGER NOT NULL DEFAULT 1,
                pinned INTEGER NOT NULL DEFAULT 0);
            CREATE INDEX clips_last_copied ON clips (last_copied_at DESC);
            CREATE VIRTUAL TABLE clips_fts USING fts5(text, content='clips', content_rowid='id', tokenize='trigram remove_diacritics 1');
            CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text); END;
            CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text); END;
            INSERT INTO clips (text, first_copied_at, last_copied_at) VALUES ('from before images', 1, 1);
            PRAGMA user_version = 2;
            """
        #expect(sqlite3_exec(db, v2, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try ClipStore(path: path)
        let old = try #require(try store.search("before").first)
        #expect(old.kind == .text)
        #expect(try store.imageData(id: old.id) == nil)

        let id = try store.insert(imageClip(9, at: 5))
        #expect(try store.imageData(id: id) == pngBytes(9))
        #expect(try store.recent(kind: .image).count == 1)
        try store.verifyIntegrity()

        // Reopening the upgraded database is safe.
        let again = try ClipStore(path: path)
        #expect(try again.recent().count == 2)
    }
}
