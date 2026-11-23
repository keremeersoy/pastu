import Foundation
import SQLite3
import Testing
@testable import PastuCore

@Suite struct OCRStoreTests {
    private func addPicture(_ store: ClipStore, tag: UInt8 = 0, at seconds: TimeInterval = 1) throws -> Int64 {
        try store.insert(.image(png: pngData(4 + Int(tag), 4), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: seconds)))
    }

    // MARK: Search

    @Test func aPictureIsFoundByTheTextInIt() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        #expect(try store.search("invoice").isEmpty)
        try store.setOCRText(id: id, "Invoice total 42 EUR")
        #expect(try store.search("invoice").map(\.id) == [id])
        #expect(try store.search("total 42").map(\.id) == [id])
        #expect(try store.search("voic").map(\.id) == [id])
    }

    @Test func shortTermsFindPicturesToo() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        try store.setOCRText(id: id, "Order 42")
        #expect(try store.search("42").map(\.id) == [id])
        #expect(try store.search("or").map(\.id) == [id])
    }

    @Test func recognisedTextDoesNotChangeWhatTheClipIs() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        try store.setOCRText(id: id, "hello")
        let clip = try #require(try store.recent().first)
        #expect(clip.kind == .image)
        #expect(clip.text.hasPrefix("[image] "))
        #expect(clip.id == id)
    }

    /// Words from a picture must not turn a text search for another clip into a picture hit by accident.
    @Test func searchStillFindsOrdinaryTextClips() throws {
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "plain note", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1)))
        let id = try addPicture(store, at: 2)
        try store.setOCRText(id: id, "something else")
        #expect(try store.search("plain").map(\.text) == ["plain note"])
    }

    @Test func replacingTheTextForgetsTheOldWords() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        try store.setOCRText(id: id, "first words")
        try store.setOCRText(id: id, "second words")
        #expect(try store.search("first").isEmpty)
        #expect(try store.search("second").map(\.id) == [id])
        try store.verifyIntegrity()
    }

    @Test func deletingAPictureRemovesItsWordsFromTheIndex() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        try store.setOCRText(id: id, "secret words")
        try store.delete(id: id)
        #expect(try store.search("secret").isEmpty)
        try store.verifyIntegrity()
    }

    @Test func clearingTheHistoryRemovesRecognisedText() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        try store.setOCRText(id: id, "secret words")
        try store.clear(keepPinned: false)
        #expect(try store.search("secret").isEmpty)
        try store.verifyIntegrity()
    }

    // MARK: Pending work

    @Test func newPicturesWaitForRecognition() throws {
        let store = try ClipStore()
        let first = try addPicture(store, tag: 0, at: 1)
        let second = try addPicture(store, tag: 1, at: 2)
        try store.insert(CapturedClip(text: "text clip", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 3)))
        // Newest first: the picture just copied is the one the user will search for.
        #expect(try store.picturesWithoutRecognisedText(limit: 10) == [second, first])
        #expect(try store.picturesWithoutRecognisedText(limit: 1) == [second])
    }

    /// A picture with no text is marked with an empty string, so it is not looked at again and again.
    @Test func aPictureWithoutTextIsNotPendingAgain() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        try store.setOCRText(id: id, "")
        #expect(try store.picturesWithoutRecognisedText(limit: 10).isEmpty)
        #expect(try store.search("anything").isEmpty)
    }

    @Test func recognisedTextOfAMissingClipIsIgnored() throws {
        let store = try ClipStore()
        try store.setOCRText(id: 999, "ghost")
        #expect(try store.search("ghost").isEmpty)
    }

    @Test func recognisedTextCanBeReadBack() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        #expect(try store.recognisedText(id: id) == nil)
        try store.setOCRText(id: id, "words")
        #expect(try store.recognisedText(id: id) == "words")
    }

    // MARK: Undo and size

    @Test func anUndoneDeleteKeepsTheRecognisedText() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        try store.setOCRText(id: id, "invoice")
        let snapshot = try #require(try store.snapshot(id: id))
        try store.delete(id: id)
        let back = try store.restore(snapshot)
        #expect(try store.search("invoice").map(\.id) == [back])
        try store.verifyIntegrity()
    }

    @Test func recognisedTextCountsTowardTheSizeEstimate() throws {
        let store = try ClipStore()
        let id = try addPicture(store)
        let before = try store.estimatedSizeInBytes()
        try store.setOCRText(id: id, String(repeating: "x", count: 1_000))
        #expect(try store.estimatedSizeInBytes() >= before + Int(1_000 * ClipStore.indexOverheadFactor))
    }

    // MARK: Migration

    @Test func aVersion3DatabaseGainsRecognisedTextAndKeepsItsClips() throws {
        let path = NSTemporaryDirectory() + "pastu-v3-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        let v3 = """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, source_bundle_id TEXT,
                first_copied_at REAL NOT NULL, last_copied_at REAL NOT NULL, copy_count INTEGER NOT NULL DEFAULT 1,
                pinned INTEGER NOT NULL DEFAULT 0, kind TEXT NOT NULL DEFAULT 'text', image BLOB);
            CREATE INDEX clips_last_copied ON clips (last_copied_at DESC);
            CREATE VIRTUAL TABLE clips_fts USING fts5(text, content='clips', content_rowid='id', tokenize='trigram remove_diacritics 1');
            CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text); END;
            CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text); END;
            INSERT INTO clips (text, first_copied_at, last_copied_at) VALUES ('from the past', 1, 1);
            INSERT INTO clips (text, first_copied_at, last_copied_at, kind, image) VALUES ('[image] abc', 2, 2, 'image', x'89504e47');
            PRAGMA user_version = 3;
            """
        #expect(sqlite3_exec(db, v3, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try ClipStore(path: path)
        #expect(try store.search("past").map(\.text) == ["from the past"])
        try store.verifyIntegrity()
        // The old picture is waiting for recognition and is searchable once it has some.
        let picture = try #require(try store.picturesWithoutRecognisedText(limit: 10).first)
        try store.setOCRText(id: picture, "receipt")
        #expect(try store.search("receipt").map(\.id) == [picture])
        try store.verifyIntegrity()
        // And the new database opens again without trouble.
        let again = try ClipStore(path: path)
        #expect(try again.search("receipt").count == 1)
        _ = store
    }
}
