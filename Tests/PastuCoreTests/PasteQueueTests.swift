import Foundation
import Observation
import Testing
@testable import PastuCore

@MainActor
@Suite struct PasteQueueTests {
    private func clips(_ texts: [String]) throws -> [StoredClip] {
        let store = try ClipStore()
        for (i, text) in texts.enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i + 1))))
        }
        // Oldest first, so tests can read the expected order off the input.
        return try store.recent().sorted { $0.lastCopiedAt < $1.lastCopiedAt }
    }

    @Test func startsEmpty() {
        let queue = PasteQueue()
        #expect(queue.isEmpty)
        #expect(queue.count == 0)
    }

    @Test func addingKeepsTheOrder() throws {
        let all = try clips(["a", "b", "c"])
        let queue = PasteQueue()
        #expect(queue.add(all[2]))
        #expect(queue.add(all[0]))
        #expect(queue.clips.map(\.text) == ["c", "a"])
        #expect(queue.position(of: all[2].id) == 1)
        #expect(queue.position(of: all[0].id) == 2)
        #expect(queue.position(of: all[1].id) == nil)
    }

    @Test func aClipCannotBeQueuedTwice() throws {
        let all = try clips(["a"])
        let queue = PasteQueue()
        #expect(queue.add(all[0]))
        #expect(!queue.add(all[0]))
        #expect(queue.count == 1)
    }

    @Test func theQueueHasALimit() throws {
        let all = try clips((0..<(PasteQueue.limit + 3)).map { "clip \($0)" })
        let queue = PasteQueue()
        let results = all.map { queue.add($0) }
        #expect(results.filter { $0 }.count == PasteQueue.limit)
        #expect(queue.count == PasteQueue.limit)
        #expect(queue.isFull)
    }

    @Test func removingAClipClosesTheGap() throws {
        let all = try clips(["a", "b", "c"])
        let queue = PasteQueue()
        all.forEach { _ = queue.add($0) }
        queue.remove(id: all[1].id)
        #expect(queue.clips.map(\.text) == ["a", "c"])
        #expect(queue.position(of: all[2].id) == 2)
        queue.remove(id: 12345)   // unknown is a no-op
        #expect(queue.count == 2)
    }

    @Test func clearEmptiesTheQueue() throws {
        let all = try clips(["a", "b"])
        let queue = PasteQueue()
        all.forEach { _ = queue.add($0) }
        queue.clear()
        #expect(queue.isEmpty)
    }

    // MARK: Plan

    @Test func theSeparatorGoesBetweenItemsNotAfterTheLast() throws {
        let all = try clips(["a", "b", "c"])
        let queue = PasteQueue()
        all.forEach { _ = queue.add($0) }
        let plan = queue.plan(separator: .newline)
        #expect(plan.map(\.clip.text) == ["a", "b", "c"])
        #expect(plan.map(\.suffix) == ["\n", "\n", ""])
    }

    @Test(arguments: [(QueueSeparator.space, " "), (.tab, "\t"), (.newline, "\n"), (.none, "")])
    func eachSeparatorHasItsText(separator: QueueSeparator, text: String) throws {
        let all = try clips(["a", "b"])
        let queue = PasteQueue()
        all.forEach { _ = queue.add($0) }
        #expect(queue.plan(separator: separator).map(\.suffix) == [text, ""])
    }

    @Test func picturesGetNoSeparator() throws {
        let store = try ClipStore()
        try store.insert(CapturedClip(text: "a", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1)))
        try store.insert(.image(png: pngData(4, 4), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2)))
        try store.insert(CapturedClip(text: "c", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 3)))
        let queue = PasteQueue()
        try store.recent().sorted { $0.lastCopiedAt < $1.lastCopiedAt }.forEach { _ = queue.add($0) }
        #expect(queue.plan(separator: .newline).map(\.suffix) == ["\n", "", ""])
    }

    @Test func anEmptyQueueHasAnEmptyPlan() {
        #expect(PasteQueue().plan(separator: .newline).isEmpty)
    }

    @Test func titlesAreReadable() {
        #expect(QueueSeparator.allCases.map(\.title) == ["New line", "Space", "Tab", "Nothing"])
    }

    @Test func queueIsObservable() throws {
        let all = try clips(["a"])
        let queue = PasteQueue()
        let changes = ChangeCounter()
        withObservationTracking { _ = queue.clips } onChange: { changes.count += 1 }
        _ = queue.add(all[0])
        #expect(changes.count == 1)
    }
}

@MainActor
@Suite struct QueueSettingsTests {
    @Test func theDefaultIsANewLine() {
        #expect(QueueSettings(store: InMemorySettings()).separator == .newline)
    }

    @Test func theChoiceSurvivesARelaunchUnderItsKey() {
        let store = InMemorySettings()
        QueueSettings(store: store).separator = .tab
        #expect(store.string(forKey: "queueSeparator") == "tab")
        #expect(QueueSettings(store: store).separator == .tab)
    }

    @Test func anUnknownValueMeansTheDefault() {
        let store = InMemorySettings()
        store.set("comma", forKey: DefaultsKeys.queueSeparator)
        #expect(QueueSettings(store: store).separator == .newline)
    }
}

@MainActor
@Suite struct ModelQueueTests {
    private func makeModel(_ texts: [String]) throws -> ClipListModel {
        let store = try ClipStore()
        for (i, text) in texts.enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: Double(i + 1))))
        }
        return ClipListModel(store: store)
    }

    @Test func addingTheSelectedClipMovesOnToTheNext() throws {
        let model = try makeModel(["a", "b", "c"])   // list: c, b, a
        model.addSelectedToQueue()
        model.addSelectedToQueue()
        #expect(model.queue.clips.map(\.text) == ["c", "b"])
        #expect(model.selectedClip?.text == "a")
        #expect(model.notice == "Added to queue (2)")
    }

    @Test func addingTheLastRowStaysOnIt() throws {
        let model = try makeModel(["a", "b"])
        model.moveToEnd()
        model.addSelectedToQueue()
        #expect(model.selectedClip?.text == "a")
        #expect(model.queue.count == 1)
    }

    @Test func addingTwiceSaysSo() throws {
        let model = try makeModel(["a", "b"])
        model.addSelectedToQueue()
        model.moveToStart()
        model.addSelectedToQueue()
        #expect(model.queue.count == 1)
        #expect(model.notice == "Already in the queue")
    }

    @Test func aFullQueueSaysSo() throws {
        let model = try makeModel((0..<(PasteQueue.limit + 2)).map { "clip \($0)" })
        for _ in 0..<(PasteQueue.limit + 1) { model.addSelectedToQueue() }
        #expect(model.queue.count == PasteQueue.limit)
        #expect(model.notice == "The queue is full (\(PasteQueue.limit))")
    }

    @Test func deletingAQueuedClipRemovesItFromTheQueue() throws {
        let model = try makeModel(["a", "b"])
        model.addSelectedToQueue()
        model.moveToStart()
        model.deleteSelected()
        #expect(model.queue.isEmpty)
    }

    /// The queue must survive the panel closing: it is pasted after the panel is gone.
    @Test func hidingThePanelKeepsTheQueue() throws {
        let model = try makeModel(["a"])
        model.addSelectedToQueue()
        model.purgeSnippets()
        model.resetForShow()
        #expect(model.queue.count == 1)
    }

    @Test func clearingTheQueueFromTheModelSaysSo() throws {
        let model = try makeModel(["a"])
        model.addSelectedToQueue()
        model.clearQueue()
        #expect(model.queue.isEmpty)
        #expect(model.notice == "Queue cleared")
        model.clearQueue()   // already empty: stays quiet
        #expect(model.notice == "Queue cleared")
    }
}
