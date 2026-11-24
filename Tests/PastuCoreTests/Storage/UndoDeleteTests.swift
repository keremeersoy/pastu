import Foundation
import Testing
@testable import PastuCore

@MainActor
@Suite struct UndoDeleteTests {
    private func makeModel(_ texts: [String]) throws -> (ClipListModel, ClipStore) {
        let store = try ClipStore()
        for (i, text) in texts.enumerated() {
            try store.insert(CapturedClip(text: text, sourceBundleIdentifier: "com.example.app", date: Date(timeIntervalSince1970: Double(i + 1))))
        }
        return (ClipListModel(store: store), store)
    }

    // MARK: Store

    @Test func aSnapshotKeepsEverythingAboutTheClip() throws {
        let (model, store) = try makeModel(["a", "b"])
        let clip = try #require(model.clips.first { $0.text == "a" })
        try store.setPinned(id: clip.id, true)
        try store.insert(CapturedClip(text: "a", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 50)))
        let snapshot = try #require(try store.snapshot(id: clip.id))
        #expect(snapshot.text == "a")
        #expect(snapshot.copyCount == 2)
        #expect(snapshot.isPinned)
        #expect(snapshot.sourceBundleIdentifier == "com.example.app")
        #expect(snapshot.lastCopiedAt == Date(timeIntervalSince1970: 50))
    }

    @Test func aSnapshotOfAMissingClipIsNil() throws {
        #expect(try ClipStore().snapshot(id: 999) == nil)
    }

    @Test func restoreBringsBackTheSameClip() throws {
        let (model, store) = try makeModel(["a", "b"])
        let clip = try #require(model.clips.first { $0.text == "a" })
        try store.setPinned(id: clip.id, true)
        let snapshot = try #require(try store.snapshot(id: clip.id))
        try store.delete(id: clip.id)
        let id = try store.restore(snapshot)
        let back = try #require(try store.recent().first { $0.id == id })
        #expect(back.text == "a")
        #expect(back.isPinned)
        #expect(back.firstCopiedAt == clip.firstCopiedAt)
        #expect(back.lastCopiedAt == clip.lastCopiedAt)
        #expect(back.copyCount == clip.copyCount)
        #expect(back.sourceBundleIdentifier == "com.example.app")
        // And it is searchable again.
        #expect(try store.search("a", limit: 10, offset: 0, kind: nil).contains { $0.id == id })
        try store.verifyIntegrity()
    }

    @Test func restoreBringsBackAPictureWithItsBytes() throws {
        let store = try ClipStore()
        let png = pngData(4, 3)
        let id = try store.insert(.image(png: png, sourceBundleIdentifier: nil, date: Date()))
        let snapshot = try #require(try store.snapshot(id: id))
        try store.delete(id: id)
        let newID = try store.restore(snapshot)
        #expect(try store.imageData(id: newID) == png)
        #expect(try store.recent().first { $0.id == newID }?.kind == .image)
    }

    /// The same text was copied again after the delete: there is one row for it, and it is not duplicated.
    @Test func restoreDoesNotDuplicateTextCopiedAgainMeanwhile() throws {
        let (model, store) = try makeModel(["a"])
        let clip = try #require(model.clips.first)
        let snapshot = try #require(try store.snapshot(id: clip.id))
        try store.delete(id: clip.id)
        let again = try store.insert(CapturedClip(text: "a", sourceBundleIdentifier: nil, date: Date()))
        let id = try store.restore(snapshot)
        #expect(id == again)
        #expect(try store.recent().count == 1)
    }

    @Test func anUndoneDeleteKeepsTheFormatting() throws {
        let store = try ClipStore()
        let rtf = Data("{\\rtf1 hi}".utf8), html = Data("<b>hi</b>".utf8)
        let id = try store.insert(CapturedClip(text: "styled", sourceBundleIdentifier: nil, date: Date(), rtf: rtf, html: html))
        let snapshot = try #require(try store.snapshot(id: id))
        try store.delete(id: id)
        let back = try store.restore(snapshot)
        #expect(try store.richContent(id: back) == RichContent(rtf: rtf, html: html))
        #expect(try store.recent().first { $0.id == back }?.hasFormatting == true)
    }

    @Test func aPlainClipStaysPlainAfterAnUndoneDelete() throws {
        let store = try ClipStore()
        let id = try store.insert(CapturedClip(text: "plain", sourceBundleIdentifier: nil, date: Date()))
        let snapshot = try #require(try store.snapshot(id: id))
        try store.delete(id: id)
        let back = try store.restore(snapshot)
        #expect(try store.richContent(id: back) == nil)
    }

    // MARK: Model

    @Test func undoRestoresTheLastDeletedClipAndSelectsIt() throws {
        let (model, _) = try makeModel(["a", "b", "c"])
        model.moveSelection(by: 1)   // "b"
        model.deleteSelected()
        #expect(model.clips.map(\.text) == ["c", "a"])
        #expect(model.canUndoDelete)
        #expect(model.undoDelete())
        #expect(model.clips.map(\.text) == ["c", "b", "a"])
        #expect(model.selectedClip?.text == "b")
        #expect(model.notice == "Restored")
        #expect(!model.canUndoDelete)
    }

    @Test func undoGoesBackOneDeleteAtATime() throws {
        let (model, _) = try makeModel(["a", "b", "c"])
        model.deleteSelected()   // c
        model.deleteSelected()   // b
        #expect(model.undoDelete())
        #expect(model.selectedClip?.text == "b")
        #expect(model.undoDelete())
        #expect(Set(model.clips.map(\.text)) == ["a", "b", "c"])
        #expect(!model.undoDelete())
    }

    @Test func undoWithNothingDeletedDoesNothing() throws {
        let (model, _) = try makeModel(["a"])
        #expect(!model.undoDelete())
        #expect(model.notice == nil)
    }

    @Test func aDeletedPinnedClipComesBackPinned() throws {
        let (model, store) = try makeModel(["a", "b"])
        let clip = try #require(model.clips.first { $0.text == "a" })
        try store.setPinned(id: clip.id, true)
        model.refresh()
        model.moveToStart()   // refresh keeps the selection on the same clip; the pinned one is now on top
        #expect(model.selectedClip?.text == "a")
        model.deleteSelected()
        _ = model.undoDelete()
        #expect(model.selectedClip?.text == "a")
        #expect(model.selectedClip?.isPinned == true)
    }

    /// A deleted clip's text must not outlive the panel: hiding it, a new show and Clear History all forget it.
    @Test func purgingForgetsWhatCouldBeRestored() throws {
        let (model, _) = try makeModel(["a", "b"])
        model.deleteSelected()
        model.purgeSnippets()
        #expect(!model.canUndoDelete)
        #expect(!model.undoDelete())

        model.deleteSelected()
        model.resetForShow()
        #expect(!model.canUndoDelete)
    }

    @Test func theUndoListIsCapped() throws {
        let (model, _) = try makeModel((0..<30).map { "clip \($0)" })
        for _ in 0..<25 { model.deleteSelected() }
        var restored = 0
        while model.undoDelete() { restored += 1 }
        #expect(restored == ClipListModel.undoLimit)
    }
}
