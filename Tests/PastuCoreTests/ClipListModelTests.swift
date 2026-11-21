import Foundation
import Testing
@testable import PastuCore

@MainActor
@Suite struct ClipListModelTests {
    private func makeStore(_ texts: [String]) throws -> ClipStore {
        let store = try ClipStore()
        for (i, text) in texts.enumerated() {
            try store.insert(CapturedClip(
                text: text, sourceBundleIdentifier: nil,
                date: Date(timeIntervalSince1970: Double(i))
            ))
        }
        return store
    }

    @Test func showsRecentClipsNewestFirstOnInit() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))
        #expect(model.clips.map(\.text) == ["c", "b", "a"])
    }

    @Test func queryFiltersResults() throws {
        let model = ClipListModel(store: try makeStore(["apple pie", "banana", "apple tart"]))
        model.query = "apple"
        #expect(Set(model.clips.map(\.text)) == ["apple pie", "apple tart"])
    }

    @Test func clearingQueryRestoresAllClips() throws {
        let model = ClipListModel(store: try makeStore(["apple", "banana"]))
        model.query = "apple"
        model.query = ""
        #expect(model.clips.count == 2)
    }

    @Test func selectionStartsAtTopAndClampsAtBothEnds() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))
        #expect(model.selectedIndex == 0)
        model.moveSelection(by: -1)
        #expect(model.selectedIndex == 0)
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 2)
    }

    @Test func selectedClipFollowsSelection() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        #expect(model.selectedClip?.text == "b")
        model.moveSelection(by: 1)
        #expect(model.selectedClip?.text == "a")
    }

    @Test func changingQueryResetsSelectionToTop() throws {
        let model = ClipListModel(store: try makeStore(["x1", "x2", "x3"]))
        model.moveSelection(by: 2)
        model.query = "x"
        #expect(model.selectedIndex == 0)
    }

    @Test func noResultsMeansNoSelection() throws {
        let model = ClipListModel(store: try makeStore(["a"]))
        model.query = "zzz"
        #expect(model.clips.isEmpty)
        #expect(model.selectedClip == nil)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 0)
    }

    @Test func refreshPicksUpNewClipsAndKeepsSelectionInRange() throws {
        let store = try makeStore(["a", "b", "c"])
        let model = ClipListModel(store: store)
        model.moveSelection(by: 2)
        for clip in try store.recent() where clip.text != "c" { try store.delete(id: clip.id) }
        model.refresh()
        #expect(model.clips.map(\.text) == ["c"])
        #expect(model.selectedIndex == 0)
    }

    @Test func selectRowJumpsToExistingRow() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))
        #expect(model.select(row: 2) == true)
        #expect(model.selectedClip?.text == "a")
    }

    @Test func selectRowIgnoresMissingRows() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        model.moveSelection(by: 1)
        #expect(model.select(row: 5) == false)
        #expect(model.select(row: -1) == false)
        #expect(model.selectedIndex == 1)
    }

    @Test func togglePinPinsTheSelectedClipAndSelectionFollowsIt() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))   // list: c, b, a
        model.moveSelection(by: 2)                                          // on "a"
        model.togglePinSelected()
        #expect(model.clips.map(\.text) == ["a", "c", "b"])
        #expect(model.selectedClip?.text == "a")
        #expect(model.selectedIndex == 0)
        #expect(model.selectedClip?.isPinned == true)
    }

    @Test func togglingAgainUnpinsAndSelectionFollowsBack() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))
        model.moveSelection(by: 2)
        model.togglePinSelected()
        model.togglePinSelected()
        #expect(model.clips.map(\.text) == ["c", "b", "a"])
        #expect(model.selectedClip?.text == "a")
        #expect(model.selectedClip?.isPinned == false)
    }

    @Test func togglePinWithNoSelectionDoesNothing() throws {
        let model = ClipListModel(store: try makeStore(["a"]))
        model.query = "zzz"
        model.togglePinSelected()
        #expect(model.clips.isEmpty)
    }
}
