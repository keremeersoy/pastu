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
}
