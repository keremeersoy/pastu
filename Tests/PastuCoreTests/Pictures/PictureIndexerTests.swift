import Foundation
import Testing
@testable import PastuCore

/// Stands in for Vision: answers from a table, records what it was asked.
final class FakeRecognizer: TextRecognizer, @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [Data: String?]
    private var calls = 0
    init(_ answers: [Data: String?] = [:]) { self.answers = answers }

    var callCount: Int { lock.withLock { calls } }

    func recognizeText(in png: Data) async -> String? {
        lock.withLock { calls += 1; return answers[png] ?? "" }
    }
}

@MainActor
@Suite struct PictureIndexerTests {
    private func addPicture(_ store: ClipStore, size: Int, at seconds: TimeInterval) throws -> (id: Int64, png: Data) {
        let png = pngData(size, size)
        return (try store.insert(.image(png: png, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: seconds))), png)
    }

    private func make(
        _ store: ClipStore, _ recognizer: FakeRecognizer, enabled: Bool = true, onIndexed: @escaping @MainActor () -> Void = {}
    ) -> PictureIndexer {
        PictureIndexer(store: store, recognizer: recognizer, isEnabled: { enabled }, onIndexed: onIndexed)
    }

    @Test func aNewPictureBecomesSearchable() async throws {
        let store = try ClipStore()
        let (id, png) = try addPicture(store, size: 8, at: 1)
        let indexer = make(store, FakeRecognizer([png: "Boarding pass gate 12"]))
        indexer.enqueue(id)
        await indexer.waitUntilIdle()
        #expect(try store.search("boarding").map(\.id) == [id])
    }

    @Test func aPictureWithoutTextIsMarkedAndNotAskedAgain() async throws {
        let store = try ClipStore()
        let (id, _) = try addPicture(store, size: 8, at: 1)
        let recognizer = FakeRecognizer()
        let indexer = make(store, recognizer)
        indexer.enqueue(id)
        await indexer.waitUntilIdle()
        #expect(try store.recognisedText(id: id) == "")
        indexer.enqueue(id)   // already marked: nothing to do
        await indexer.waitUntilIdle()
        #expect(recognizer.callCount == 1)
    }

    @Test func textClipsAreIgnored() async throws {
        let store = try ClipStore()
        let id = try store.insert(CapturedClip(text: "note", sourceBundleIdentifier: nil, date: Date()))
        let recognizer = FakeRecognizer()
        let indexer = make(store, recognizer)
        indexer.enqueue(id)
        await indexer.waitUntilIdle()
        #expect(recognizer.callCount == 0)
    }

    @Test func whenSwitchedOffNothingIsRecognisedAndThePictureStaysPending() async throws {
        let store = try ClipStore()
        let (id, _) = try addPicture(store, size: 8, at: 1)
        let recognizer = FakeRecognizer()
        let indexer = make(store, recognizer, enabled: false)
        indexer.enqueue(id)
        await indexer.waitUntilIdle()
        #expect(recognizer.callCount == 0)
        #expect(try store.picturesWithoutRecognisedText(limit: 5) == [id])
    }

    @Test func aFailedRecognitionStaysPendingAndTheRestContinue() async throws {
        let store = try ClipStore()
        let (first, firstPNG) = try addPicture(store, size: 8, at: 1)
        let (second, secondPNG) = try addPicture(store, size: 9, at: 2)
        let indexer = make(store, FakeRecognizer([firstPNG: nil, secondPNG: "works"]))
        indexer.enqueue(first)
        indexer.enqueue(second)
        await indexer.waitUntilIdle()
        #expect(try store.recognisedText(id: first) == nil)
        #expect(try store.recognisedText(id: second) == "works")
    }

    @Test func aPictureDeletedBeforeItsTurnIsSkipped() async throws {
        let store = try ClipStore()
        let (id, png) = try addPicture(store, size: 8, at: 1)
        let recognizer = FakeRecognizer([png: "ghost"])
        let indexer = make(store, recognizer)
        indexer.enqueue(id)
        try store.delete(id: id)
        await indexer.waitUntilIdle()
        #expect(try store.search("ghost").isEmpty)
        try store.verifyIntegrity()
    }

    @Test func existingPicturesAreCaughtUpNewestFirst() async throws {
        let store = try ClipStore()
        let old = try addPicture(store, size: 8, at: 1)
        let new = try addPicture(store, size: 9, at: 2)
        let indexer = make(store, FakeRecognizer([old.png: "old words", new.png: "new words"]))
        indexer.catchUp()
        await indexer.waitUntilIdle()
        #expect(try store.search("old words").map(\.id) == [old.id])
        #expect(try store.search("new words").map(\.id) == [new.id])
    }

    @Test func theSamePictureQueuedTwiceIsRecognisedOnce() async throws {
        let store = try ClipStore()
        let (id, png) = try addPicture(store, size: 8, at: 1)
        let recognizer = FakeRecognizer([png: "once"])
        let indexer = make(store, recognizer)
        indexer.enqueue(id)
        indexer.enqueue(id)
        await indexer.waitUntilIdle()
        #expect(recognizer.callCount == 1)
    }

    @Test func theListIsToldWhenSomethingWasIndexed() async throws {
        let store = try ClipStore()
        let (id, png) = try addPicture(store, size: 8, at: 1)
        var told = 0
        let indexer = make(store, FakeRecognizer([png: "words"])) { told += 1 }
        indexer.enqueue(id)
        await indexer.waitUntilIdle()
        #expect(told == 1)
    }

    @Test func veryLongTextIsCut() async throws {
        let store = try ClipStore()
        let (id, png) = try addPicture(store, size: 8, at: 1)
        let indexer = make(store, FakeRecognizer([png: String(repeating: "word ", count: 50_000)]))
        indexer.enqueue(id)
        await indexer.waitUntilIdle()
        #expect(try #require(try store.recognisedText(id: id)).count <= PictureIndexer.maxCharacters)
    }
}
