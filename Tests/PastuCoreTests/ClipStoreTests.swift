import Foundation
import SQLite3
import Testing
@testable import PastuCore

@Suite struct ClipStoreTests {
    private func clip(_ text: String, at seconds: TimeInterval, app: String? = nil) -> CapturedClip {
        CapturedClip(text: text, sourceBundleIdentifier: app, date: Date(timeIntervalSince1970: seconds))
    }

    @Test func recentReturnsNewestFirst() throws {
        let store = try ClipStore()
        try store.insert(clip("old", at: 100))
        try store.insert(clip("new", at: 200))
        #expect(try store.recent().map(\.text) == ["new", "old"])
    }

    @Test func recentRespectsLimit() throws {
        let store = try ClipStore()
        for i in 0..<5 { try store.insert(clip("clip \(i)", at: Double(i))) }
        #expect(try store.recent(limit: 2).count == 2)
    }

    @Test func storesSourceApp() throws {
        let store = try ClipStore()
        try store.insert(clip("hello", at: 1, app: "com.apple.Safari"))
        #expect(try store.recent().first?.sourceBundleIdentifier == "com.apple.Safari")
    }

    @Test func duplicateTextMergesIntoOneRow() throws {
        let store = try ClipStore()
        let first = try store.insert(clip("same", at: 100))
        let second = try store.insert(clip("same", at: 300))
        let clips = try store.recent()
        #expect(first == second)
        #expect(clips.count == 1)
        let merged = try #require(clips.first)
        #expect(merged.copyCount == 2)
        #expect(merged.firstCopiedAt == Date(timeIntervalSince1970: 100))
        #expect(merged.lastCopiedAt == Date(timeIntervalSince1970: 300))
    }

    @Test func recopyMovesOlderClipToTop() throws {
        let store = try ClipStore()
        try store.insert(clip("a", at: 100))
        try store.insert(clip("b", at: 200))
        try store.insert(clip("a", at: 300))
        #expect(try store.recent().map(\.text) == ["a", "b"])
    }

    @Test func searchFindsWordPrefixCaseInsensitively() throws {
        let store = try ClipStore()
        try store.insert(clip("Hello World", at: 1))
        try store.insert(clip("unrelated", at: 2))
        #expect(try store.search("wor").map(\.text) == ["Hello World"])
        #expect(try store.search("HELLO").map(\.text) == ["Hello World"])
    }

    @Test func searchRequiresAllWords() throws {
        let store = try ClipStore()
        try store.insert(clip("alpha beta", at: 1))
        try store.insert(clip("alpha gamma", at: 2))
        #expect(try store.search("alpha beta").map(\.text) == ["alpha beta"])
    }

    @Test func searchSurvivesFTSSyntaxCharacters() throws {
        let store = try ClipStore()
        try store.insert(clip("say \"quoted\" (text) AND more", at: 1))
        // Must not throw a syntax error and must still find the clip.
        #expect(try store.search("\"quoted\" (text").count == 1)
        #expect(try store.search("AND").count == 1)
        #expect(try store.search("*").isEmpty)
    }

    @Test func emptyQueryReturnsRecent() throws {
        let store = try ClipStore()
        try store.insert(clip("one", at: 1))
        #expect(try store.search("   ").map(\.text) == ["one"])
    }

    @Test func searchStaysConsistentAfterDuplicateUpdate() throws {
        let store = try ClipStore()
        try store.insert(clip("findme", at: 1))
        try store.insert(clip("findme", at: 2))
        #expect(try store.search("findme").count == 1)
    }

    @Test func deleteRemovesFromHistoryAndSearch() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("gone", at: 1))
        try store.delete(id: id)
        #expect(try store.recent().isEmpty)
        #expect(try store.search("gone").isEmpty)
    }

    @Test func markUsedMovesClipToTopWithoutCountingAsCopy() throws {
        let store = try ClipStore()
        let oldID = try store.insert(clip("old", at: 100))
        try store.insert(clip("new", at: 200))
        try store.markUsed(id: oldID, at: Date(timeIntervalSince1970: 300))

        let clips = try store.recent()
        #expect(clips.map(\.text) == ["old", "new"])
        let old = try #require(clips.first)
        #expect(old.copyCount == 1)
        #expect(old.lastCopiedAt == Date(timeIntervalSince1970: 300))
        #expect(old.firstCopiedAt == Date(timeIntervalSince1970: 100))
    }

    @Test func markUsedKeepsSearchIndexInSync() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("findable", at: 1))
        try store.markUsed(id: id, at: Date(timeIntervalSince1970: 2))
        try store.verifyIntegrity()
        #expect(try store.search("findable").count == 1)
    }

    @Test func searchIndexStaysInSyncWithTable() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("temporary", at: 1))
        try store.insert(clip("temporary", at: 2))
        try store.insert(clip("permanent", at: 3))
        try store.verifyIntegrity()
        try store.delete(id: id)
        try store.verifyIntegrity()
    }

    @Test func persistsAcrossReopen() throws {
        let path = NSTemporaryDirectory() + "pastu-test-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let first = try ClipStore(path: path)
        try first.insert(clip("kept", at: 1))

        let second = try ClipStore(path: path)
        #expect(try second.recent().map(\.text) == ["kept"])
    }

    // MARK: Retention

    private let day: TimeInterval = 24 * 3600

    @Test func pruneRemovesClipsOlderThanMaxAge() throws {
        let store = try ClipStore()
        let now = Date(timeIntervalSince1970: 100 * day)
        try store.insert(clip("ancient", at: 100 * day - 40 * day))
        try store.insert(clip("recent", at: 100 * day - 10 * day))

        let removed = try store.prune(RetentionPolicy(maxCount: nil, maxAge: 30 * day), now: now)
        #expect(removed == 1)
        #expect(try store.recent().map(\.text) == ["recent"])
    }

    @Test func pruneKeepsOnlyTheNewestWhenOverMaxCount() throws {
        let store = try ClipStore()
        for i in 1...5 { try store.insert(clip("clip \(i)", at: Double(i))) }

        let removed = try store.prune(RetentionPolicy(maxCount: 3, maxAge: nil))
        #expect(removed == 2)
        #expect(try store.recent().map(\.text) == ["clip 5", "clip 4", "clip 3"])
    }

    @Test func pruneAppliesBothLimits() throws {
        let store = try ClipStore()
        let now = Date(timeIntervalSince1970: 100 * day)
        try store.insert(clip("ancient", at: 100 * day - 90 * day))
        try store.insert(clip("a", at: 100 * day - 3 * day))
        try store.insert(clip("b", at: 100 * day - 2 * day))
        try store.insert(clip("c", at: 100 * day - 1 * day))

        let removed = try store.prune(RetentionPolicy(maxCount: 2, maxAge: 30 * day), now: now)
        #expect(removed == 2)
        #expect(try store.recent().map(\.text) == ["c", "b"])
    }

    @Test func pruneWithoutLimitsRemovesNothing() throws {
        let store = try ClipStore()
        try store.insert(clip("old", at: 1))
        #expect(try store.prune(RetentionPolicy(maxCount: nil, maxAge: nil)) == 0)
        #expect(try store.recent().count == 1)
    }

    @Test func pruneWithNothingToRemoveReturnsZero() throws {
        let store = try ClipStore()
        try store.insert(clip("fresh", at: Date().timeIntervalSince1970))
        #expect(try store.prune(RetentionPolicy()) == 0)
    }

    @Test func prunedClipsAreGoneFromSearchAndIndexStaysConsistent() throws {
        let store = try ClipStore()
        try store.insert(clip("remove me", at: 1))
        try store.insert(clip("keep me", at: 2))
        try store.prune(RetentionPolicy(maxCount: 1, maxAge: nil))
        try store.verifyIntegrity()
        #expect(try store.search("remove").isEmpty)
        #expect(try store.search("keep").count == 1)
    }

    // MARK: File permissions

    private func permissions(of path: String) throws -> Int {
        let value = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
        return try #require(value).intValue
    }

    @Test func newDatabaseFileIsOwnerOnly() throws {
        let path = NSTemporaryDirectory() + "pastu-perm-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }

        _ = try ClipStore(path: path)
        #expect(try permissions(of: path) == 0o600)
    }

    @Test func existingLooseDatabaseFileIsTightenedOnOpen() throws {
        let path = NSTemporaryDirectory() + "pastu-perm-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        FileManager.default.createFile(atPath: path, contents: nil, attributes: [.posixPermissions: 0o644])

        _ = try ClipStore(path: path)
        #expect(try permissions(of: path) == 0o600)
    }

    @Test func liveLooseSidecarFilesAreTightenedWhenReopened() throws {
        let path = NSTemporaryDirectory() + "pastu-perm-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }

        // Simulates an app killed mid-session: the sidecars outlive it with whatever mode they had.
        // The first connection stays open so SQLite keeps (rather than recreates) the -shm file.
        let first = try ClipStore(path: path)
        try first.insert(clip("data", at: 1))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path + "-shm")
        #expect(try permissions(of: path + "-shm") == 0o644)

        let second = try ClipStore(path: path)
        #expect(try permissions(of: path + "-shm") == 0o600)
        _ = (first, second)
    }

    @Test func walSidecarFilesAreOwnerOnlyToo() throws {
        let path = NSTemporaryDirectory() + "pastu-perm-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }

        let store = try ClipStore(path: path)
        try store.insert(clip("secret-ish", at: 1))
        for suffix in ["-wal", "-shm"] where FileManager.default.fileExists(atPath: path + suffix) {
            #expect(try permissions(of: path + suffix) == 0o600)
        }
        _ = store
    }

    // MARK: Pins

    @Test func pinnedClipsComeFirstInRecent() throws {
        let store = try ClipStore()
        let old = try store.insert(clip("old", at: 1))
        try store.insert(clip("new", at: 2))
        try store.setPinned(id: old, true)
        #expect(try store.recent().map(\.text) == ["old", "new"])
        #expect(try store.recent().map(\.isPinned) == [true, false])
    }

    @Test func pinnedClipsComeFirstInSearch() throws {
        let store = try ClipStore()
        let old = try store.insert(clip("note one", at: 1))
        try store.insert(clip("note two", at: 2))
        try store.setPinned(id: old, true)
        #expect(try store.search("note").map(\.text) == ["note one", "note two"])
    }

    @Test func unpinRestoresRecencyOrder() throws {
        let store = try ClipStore()
        let old = try store.insert(clip("old", at: 1))
        try store.insert(clip("new", at: 2))
        try store.setPinned(id: old, true)
        try store.setPinned(id: old, false)
        #expect(try store.recent().map(\.text) == ["new", "old"])
        #expect(try store.recent().allSatisfy { !$0.isPinned })
    }

    @Test func pinningDoesNotCountAsACopy() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("a", at: 5))
        try store.setPinned(id: id, true)
        let pinned = try #require(try store.recent().first)
        #expect(pinned.copyCount == 1)
        #expect(pinned.lastCopiedAt == Date(timeIntervalSince1970: 5))
    }

    @Test func copyingAPinnedClipAgainKeepsItPinned() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("keep", at: 1))
        try store.setPinned(id: id, true)
        try store.insert(clip("keep", at: 2))
        let clips = try store.recent()
        #expect(clips.count == 1)
        #expect(clips.first?.isPinned == true)
    }

    @Test func pruneNeverRemovesPinnedClips() throws {
        let store = try ClipStore()
        let now = Date(timeIntervalSince1970: 100 * day)
        let ancient = try store.insert(clip("pinned ancient", at: 100 * day - 90 * day))
        try store.setPinned(id: ancient, true)
        try store.insert(clip("old unpinned", at: 100 * day - 80 * day))
        for i in 1...3 { try store.insert(clip("fresh \(i)", at: 100 * day - Double(i) * 3600)) }

        // Age rule removes the 80-day-old unpinned clip but must spare the pinned 90-day-old one.
        try store.prune(RetentionPolicy(maxCount: nil, maxAge: 30 * day), now: now)
        #expect(try store.recent().map(\.text).contains("pinned ancient"))
        #expect(try store.recent().map(\.text).contains("old unpinned") == false)

        // Count rule keeps 2 unpinned clips; pinned ones do not count against the limit.
        try store.prune(RetentionPolicy(maxCount: 2, maxAge: nil), now: now)
        let texts = try store.recent().map(\.text)
        #expect(texts.count == 3)
        #expect(texts.first == "pinned ancient")
    }

    @Test func pinningAMissingClipIsHarmless() throws {
        let store = try ClipStore()
        try store.setPinned(id: 12345, true)
        #expect(try store.recent().isEmpty)
    }

    @Test func databaseCreatedBeforePinsStillOpensWithItsData() throws {
        let path = NSTemporaryDirectory() + "pastu-old-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }

        // The exact schema shipped before pins existed, with one indexed clip in it.
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        let legacy = """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, source_bundle_id TEXT,
                first_copied_at REAL NOT NULL, last_copied_at REAL NOT NULL, copy_count INTEGER NOT NULL DEFAULT 1);
            CREATE INDEX clips_last_copied ON clips (last_copied_at DESC);
            CREATE VIRTUAL TABLE clips_fts USING fts5(text, content='clips', content_rowid='id', tokenize='unicode61 remove_diacritics 2');
            CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text); END;
            CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text); END;
            INSERT INTO clips (text, first_copied_at, last_copied_at) VALUES ('from the past', 1, 1);
            """
        #expect(sqlite3_exec(db, legacy, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try ClipStore(path: path)
        let clips = try store.search("past")
        let migrated = try #require(clips.first)
        #expect(migrated.text == "from the past")
        #expect(migrated.isPinned == false)
        #expect(try store.search("ast").count == 1)   // substring search works after the full upgrade chain

        try store.setPinned(id: migrated.id, true)
        #expect(try store.recent().first?.isPinned == true)
        try store.verifyIntegrity()
    }

    @Test func reopeningAMigratedDatabaseIsSafe() throws {
        let path = NSTemporaryDirectory() + "pastu-reopen-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }
        let first = try ClipStore(path: path)
        let id = try first.insert(clip("persist", at: 1))
        try first.setPinned(id: id, true)

        let second = try ClipStore(path: path)
        #expect(try second.recent().first?.isPinned == true)
        _ = first
    }

    // MARK: Substring search

    @Test func searchFindsSubstringsInsideWords() throws {
        let store = try ClipStore()
        try store.insert(clip("Hello World", at: 1))
        #expect(try store.search("ello").map(\.text) == ["Hello World"])
        #expect(try store.search("orl").map(\.text) == ["Hello World"])
        #expect(try store.search("xyz").isEmpty)
    }

    @Test func searchIgnoresCaseAndDiacritics() throws {
        let store = try ClipStore()
        try store.insert(clip("Café Münster", at: 1))
        #expect(try store.search("CAFE").count == 1)
        #expect(try store.search("munster").count == 1)
        #expect(try store.search("CAFÉ").count == 1)
    }

    @Test func shortQueriesStillWork() throws {
        let store = try ClipStore()
        try store.insert(clip("Hello World", at: 1))
        try store.insert(clip("unrelated", at: 2))
        #expect(try store.search("he").map(\.text) == ["Hello World"])
        #expect(try store.search("o").map(\.text) == ["Hello World"])
        #expect(try store.search("q").isEmpty)
    }

    @Test func shortAndLongTermsCanBeMixed() throws {
        let store = try ClipStore()
        try store.insert(clip("Hello World", at: 1))
        try store.insert(clip("Hello Mars", at: 2))
        #expect(try store.search("hello wo").map(\.text) == ["Hello World"])
        #expect(try store.search("ar hello").map(\.text) == ["Hello Mars"])
    }

    @Test func punctuationIsSearchable() throws {
        let store = try ClipStore()
        try store.insert(clip("see https://example.com/a", at: 1))
        try store.insert(clip("no link here", at: 2))
        #expect(try store.search("://").map(\.text) == ["see https://example.com/a"])
        #expect(try store.search("https://").map(\.text) == ["see https://example.com/a"])
    }

    @Test func quoteCharactersArePartOfTheSearch() throws {
        let store = try ClipStore()
        try store.insert(clip("plain quoted word", at: 1))
        try store.insert(clip("say \"quoted\" here", at: 2))
        // Searching with the quotes must only find the clip that really contains them.
        #expect(try store.search("\"quoted\"").map(\.text) == ["say \"quoted\" here"])
    }

    @Test func everyTermMustMatchSomewhere() throws {
        let store = try ClipStore()
        try store.insert(clip("alpha beta", at: 1))
        #expect(try store.search("lph eta").count == 1)
        #expect(try store.search("lph zzz").isEmpty)
    }

    @Test func substringResultsAreNewestFirst() throws {
        let store = try ClipStore()
        try store.insert(clip("project old", at: 1))
        try store.insert(clip("project new", at: 2))
        #expect(try store.search("oject").map(\.text) == ["project new", "project old"])
    }

    @Test func databaseWithTheOldWordIndexIsUpgradedToSubstringSearch() throws {
        let path = NSTemporaryDirectory() + "pastu-v1-\(UUID().uuidString).sqlite"
        defer { for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: path + suffix) } }

        // Schema as shipped with pins (version 1): word-based index.
        var db: OpaquePointer?
        #expect(sqlite3_open(path, &db) == SQLITE_OK)
        let v1 = """
            CREATE TABLE clips (
                id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL UNIQUE, source_bundle_id TEXT,
                first_copied_at REAL NOT NULL, last_copied_at REAL NOT NULL, copy_count INTEGER NOT NULL DEFAULT 1,
                pinned INTEGER NOT NULL DEFAULT 0);
            CREATE INDEX clips_last_copied ON clips (last_copied_at DESC);
            CREATE VIRTUAL TABLE clips_fts USING fts5(text, content='clips', content_rowid='id', tokenize='unicode61 remove_diacritics 2');
            CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN INSERT INTO clips_fts (rowid, text) VALUES (new.id, new.text); END;
            CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN INSERT INTO clips_fts (clips_fts, rowid, text) VALUES ('delete', old.id, old.text); END;
            INSERT INTO clips (text, first_copied_at, last_copied_at) VALUES ('from the past', 1, 1);
            PRAGMA user_version = 1;
            """
        #expect(sqlite3_exec(db, v1, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try ClipStore(path: path)
        #expect(try store.search("ast").map(\.text) == ["from the past"])
        try store.verifyIntegrity()

        // New copies keep being indexed, and deletes keep the index clean.
        let id = try store.insert(clip("another clip", at: 2))
        #expect(try store.search("nother").count == 1)
        try store.delete(id: id)
        try store.verifyIntegrity()
        #expect(try store.search("nother").isEmpty)
    }

    // MARK: Total size cap

    /// A clip whose text is exactly `bytes` bytes long (ASCII), unique per `tag`.
    private func sized(_ tag: Int, bytes: Int = 100, at seconds: TimeInterval) -> CapturedClip {
        let prefix = "\(tag)-"
        return clip(prefix + String(repeating: "x", count: bytes - prefix.utf8.count), at: seconds)
    }

    @Test func estimatedSizeIsTextBytesTimesOverheadFactor() throws {
        let store = try ClipStore()
        try store.insert(sized(1, at: 1))
        try store.insert(sized(2, at: 2))
        #expect(try store.estimatedSizeInBytes() == Int(200 * ClipStore.indexOverheadFactor))
    }

    @Test func overheadFactorIsDocumentedValue() {
        #expect(ClipStore.indexOverheadFactor == 4.5)
    }

    @Test func estimatedSizeCountsBytesNotCharacters() throws {
        let store = try ClipStore()
        try store.insert(clip("ççççç", at: 1)) // 5 characters, 10 bytes
        #expect(try store.estimatedSizeInBytes() == Int(10 * ClipStore.indexOverheadFactor))
    }

    @Test func pruneDeletesOldestUntilUnderTheSizeCap() throws {
        let store = try ClipStore()
        for i in 1...5 { try store.insert(sized(i, at: Double(i))) } // 5 * 100 * 4.5 = 2250
        let cap = Int(2.5 * 100 * ClipStore.indexOverheadFactor)      // room for exactly 2
        let removed = try store.prune(RetentionPolicy(maxCount: nil, maxAge: nil, maxTotalBytes: cap))
        #expect(removed == 3)
        #expect(try store.recent().map(\.text.count) == [100, 100])
        #expect(try store.recent().map { $0.text.prefix(2) } == ["5-", "4-"])
        #expect(try store.estimatedSizeInBytes() <= cap)
        try store.verifyIntegrity()
    }

    @Test func sizeCapKeepsEverythingWhenAlreadyUnderTheCap() throws {
        let store = try ClipStore()
        for i in 1...3 { try store.insert(sized(i, at: Double(i))) }
        let exact = try store.estimatedSizeInBytes()
        #expect(try store.prune(RetentionPolicy(maxCount: nil, maxAge: nil, maxTotalBytes: exact)) == 0)
        #expect(try store.recent().count == 3)
    }

    @Test func sizeCapNeverDeletesPinnedClips() throws {
        let store = try ClipStore()
        let pinned = try store.insert(sized(1, at: 1)) // the oldest
        try store.setPinned(id: pinned, true)
        for i in 2...4 { try store.insert(sized(i, at: Double(i))) }
        // The cap is smaller than the pinned clip alone: all unpinned go, the pinned one stays.
        let removed = try store.prune(RetentionPolicy(maxCount: nil, maxAge: nil, maxTotalBytes: 10))
        #expect(removed == 3)
        #expect(try store.recent().map(\.id) == [pinned])
    }

    @Test func nilSizeCapMeansUnlimited() throws {
        let store = try ClipStore()
        for i in 1...3 { try store.insert(sized(i, at: Double(i))) }
        #expect(try store.prune(RetentionPolicy(maxCount: nil, maxAge: nil, maxTotalBytes: nil)) == 0)
    }

    @Test func defaultSizeCapIs200MB() {
        #expect(RetentionPolicy().maxTotalBytes == 200 * 1024 * 1024)
    }

    @Test func sizeCapRemovesOldestByLastCopiedNotByInsertOrder() throws {
        let store = try ClipStore()
        try store.insert(sized(1, at: 10))
        try store.insert(sized(2, at: 20))
        try store.insert(sized(1, at: 30)) // re-copy: clip 1 is now the newest
        let cap = Int(1.5 * 100 * ClipStore.indexOverheadFactor)
        try store.prune(RetentionPolicy(maxCount: nil, maxAge: nil, maxTotalBytes: cap))
        #expect(try store.recent().map { $0.text.prefix(2) } == ["1-"])
    }

    // MARK: Clear history

    @Test func clearRemovesEverythingAndTheSearchIndexWithIt() throws {
        let store = try ClipStore()
        for i in 1...3 { try store.insert(clip("clip number \(i)", at: Double(i))) }
        #expect(try store.clear(keepPinned: false) == 3)
        #expect(try store.recent().isEmpty)
        #expect(try store.search("number").isEmpty)
        try store.verifyIntegrity()
    }

    @Test func clearKeepingPinnedLeavesOnlyPinnedClips() throws {
        let store = try ClipStore()
        let keep = try store.insert(clip("keep me", at: 1))
        try store.insert(clip("drop me", at: 2))
        try store.setPinned(id: keep, true)
        #expect(try store.clear(keepPinned: true) == 1)
        #expect(try store.recent().map(\.text) == ["keep me"])
        #expect(try store.search("keep").count == 1)
        #expect(try store.search("drop").isEmpty)
        try store.verifyIntegrity()
    }

    @Test func clearNotKeepingPinnedRemovesPinnedToo() throws {
        let store = try ClipStore()
        let id = try store.insert(clip("pinned", at: 1))
        try store.setPinned(id: id, true)
        #expect(try store.clear(keepPinned: false) == 1)
        #expect(try store.recent().isEmpty)
    }

    @Test func clearOnEmptyStoreReturnsZero() throws {
        #expect(try ClipStore().clear(keepPinned: true) == 0)
    }

    @Test func storeIsUsableAfterClear() throws {
        let store = try ClipStore()
        try store.insert(clip("before", at: 1))
        try store.clear(keepPinned: true)
        try store.insert(clip("after", at: 2))
        #expect(try store.search("after").count == 1)
    }
}
