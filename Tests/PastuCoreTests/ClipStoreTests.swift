import Foundation
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
}
