import Foundation
import SQLite3
import Testing
@testable import PastuCore

@Suite struct ClipStoreFileTests {
    private func filesClip(_ paths: [String], at seconds: TimeInterval = 1, app: String? = "com.apple.finder") -> CapturedClip {
        .files(paths: paths, sourceBundleIdentifier: app, date: Date(timeIntervalSince1970: seconds))
    }

    // MARK: Storing

    @Test func aFileClipKeepsItsPathsAndKind() throws {
        let store = try ClipStore()
        let id = try store.insert(filesClip(["/Users/me/Q3 report.pdf", "/Users/me/notes.txt"]))
        let clip = try #require(try store.recent().first { $0.id == id })
        #expect(clip.kind == .file)
        #expect(clip.files == ["/Users/me/Q3 report.pdf", "/Users/me/notes.txt"])
        #expect(clip.fileNames == ["Q3 report.pdf", "notes.txt"])
        #expect(clip.sourceBundleIdentifier == "com.apple.finder")
    }

    @Test func textAndPictureClipsHaveNoFiles() throws {
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "hello", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1)))
        try store.insert(.image(png: pngData(4, 4), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2)))
        #expect(try store.recent().allSatisfy { $0.files.isEmpty })
    }

    @Test func theSameFilesCopiedAgainMergeIntoOneRow() throws {
        let store = try ClipStore()
        let first = try store.insert(filesClip(["/a/one.txt", "/a/two.txt"], at: 1))
        let second = try store.insert(filesClip(["/a/one.txt", "/a/two.txt"], at: 2))
        #expect(first == second)
        let clip = try #require(try store.recent().first)
        #expect(clip.copyCount == 2)
        #expect(try store.recent().count == 1)
    }

    /// Two different folders with a file of the same name are two different copies; pasting one must not paste the other.
    @Test func sameNamesInDifferentFoldersStaySeparate() throws {
        let store = try ClipStore()
        try store.insert(filesClip(["/work/report.pdf"], at: 1))
        try store.insert(filesClip(["/archive/report.pdf"], at: 2))
        let clips = try store.recent()
        #expect(clips.count == 2)
        #expect(Set(clips.map(\.files)) == [["/work/report.pdf"], ["/archive/report.pdf"]])
    }

    @Test func aFileClipsKeyIsStableAndDoesNotLookLikeAPath() {
        let one = filesClip(["/a/one.txt"])
        #expect(one.text.hasPrefix("[files] "))
        #expect(one.text == filesClip(["/a/one.txt"]).text)
        #expect(one.text != filesClip(["/a/two.txt"]).text)
        #expect(!one.text.contains("one.txt"))
    }

    // MARK: Kinds and search

    @Test func theKindFilterSeparatesFilesFromEverythingElse() throws {
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "plain note", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1)))
        try store.insert(CapturedClip(text: "https://example.com", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2)))
        try store.insert(.image(png: pngData(4, 4), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 3)))
        try store.insert(filesClip(["/a/one.txt"], at: 4))
        #expect(try store.recent(kind: .file).map(\.kind) == [.file])
        #expect(try store.recent(kind: .text).map(\.text) == ["plain note"])
        #expect(try store.recent(kind: .link).count == 1)
        #expect(try store.recent(kind: .image).count == 1)
        #expect(try store.recent().count == 4)
    }

    @Test func filesAreFoundByTheirNames() throws {
        let store = try ClipStore()
        let id = try store.insert(filesClip(["/Users/me/Documents/Q3 report.pdf", "/Users/me/notes.txt"]))
        #expect(try store.search("report").map(\.id) == [id])
        #expect(try store.search("NOTES").map(\.id) == [id])
        #expect(try store.search("ort.p").map(\.id) == [id])
        #expect(try store.search("q3").map(\.id) == [id], "short terms work too")
        #expect(try store.search("invoice").isEmpty)
    }

    @Test func aFolderNameInThePathIsNotSearchedOnlyTheNames() throws {
        let store = try ClipStore()
        try store.insert(filesClip(["/Users/secretproject/one.txt"]))
        #expect(try store.search("secretproject").isEmpty)
    }

    @Test func searchWithinTheFilesFilter() throws {
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "report in text", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1)))
        let id = try store.insert(filesClip(["/a/report.pdf"], at: 2))
        #expect(try store.search("report", kind: .file).map(\.id) == [id])
    }

    // MARK: Delete, undo, size

    @Test func deletingAFileClipCleansTheIndex() throws {
        let store = try ClipStore()
        let id = try store.insert(filesClip(["/a/report.pdf"]))
        try store.delete(id: id)
        #expect(try store.search("report").isEmpty)
        try store.verifyIntegrity()
    }

    @Test func anUndoneDeleteKeepsTheFiles() throws {
        let store = try ClipStore()
        let id = try store.insert(filesClip(["/a/report.pdf", "/b/notes.txt"]))
        let snapshot = try #require(try store.snapshot(id: id))
        try store.delete(id: id)
        let back = try store.restore(snapshot)
        let clip = try #require(try store.recent().first { $0.id == back })
        #expect(clip.kind == .file)
        #expect(clip.files == ["/a/report.pdf", "/b/notes.txt"])
        #expect(try store.search("report").map(\.id) == [back])
        try store.verifyIntegrity()
    }

    @Test func filesAreNeverTakenForPicturesToRead() throws {
        let store = try ClipStore()
        let id = try store.insert(filesClip(["/a/photo.png"]))
        #expect(try store.picturesWithoutRecognisedText(limit: 10).isEmpty)
        try store.setOCRText(id: id, "should not apply")
        #expect(try store.search("should").isEmpty)
    }

    @Test func manyFilesAreStoredWhole() throws {
        let store = try ClipStore()
        let paths = (0..<150).map { "/a/file \($0).txt" }
        let id = try store.insert(filesClip(paths))
        #expect(try store.recent().first { $0.id == id }?.files == paths)
    }

    @Test func pathsWithOddCharactersSurvive() throws {
        let store = try ClipStore()
        let paths = ["/a/Ünïcode ✓.txt", "/a/quote\"and\\slash.txt", "/a/new\nline.txt"]
        let id = try store.insert(filesClip(paths))
        #expect(try store.recent().first { $0.id == id }?.files == paths)
    }

    // MARK: Migration

    @Test func aVersion5DatabaseGainsFilesAndKeepsItsClips() throws {
        let path = NSTemporaryDirectory() + "pastu-v5-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        let v5 = """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, source_bundle_id TEXT,
                first_copied_at REAL NOT NULL, last_copied_at REAL NOT NULL, copy_count INTEGER NOT NULL DEFAULT 1,
                pinned INTEGER NOT NULL DEFAULT 0, kind TEXT NOT NULL DEFAULT 'text', image BLOB, ocr_text TEXT,
                rtf BLOB, html BLOB);
            CREATE INDEX clips_last_copied ON clips (last_copied_at DESC);
            CREATE VIRTUAL TABLE clips_fts USING fts5(text, ocr_text, content='clips', content_rowid='id', tokenize='trigram remove_diacritics 1');
            CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN INSERT INTO clips_fts (rowid, text, ocr_text) VALUES (new.id, new.text, new.ocr_text); END;
            CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN INSERT INTO clips_fts (clips_fts, rowid, text, ocr_text) VALUES ('delete', old.id, old.text, old.ocr_text); END;
            CREATE TRIGGER clips_au AFTER UPDATE OF ocr_text ON clips BEGIN
                INSERT INTO clips_fts (clips_fts, rowid, text, ocr_text) VALUES ('delete', old.id, old.text, old.ocr_text);
                INSERT INTO clips_fts (rowid, text, ocr_text) VALUES (new.id, new.text, new.ocr_text); END;
            INSERT INTO clips (text, first_copied_at, last_copied_at) VALUES ('from v5', 1, 1);
            PRAGMA user_version = 5;
            """
        #expect(sqlite3_exec(db, v5, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try ClipStore(path: path)
        #expect(try store.search("v5").map(\.text) == ["from v5"])
        let id = try store.insert(filesClip(["/a/after.txt"], at: 2))
        #expect(try store.recent().first { $0.id == id }?.files == ["/a/after.txt"])
        try store.verifyIntegrity()
        #expect(try ClipStore(path: path).recent().count == 2)
        _ = store
    }
}
