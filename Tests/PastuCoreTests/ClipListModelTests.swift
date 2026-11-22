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

    // MARK: Type filter

    @Test func filterShowsOnlyLinksOrOnlyText() throws {
        let model = ClipListModel(store: try makeStore(["note", "https://a.com", "other", "https://b.com"]))
        model.filter = .links
        #expect(model.clips.map(\.text) == ["https://b.com", "https://a.com"])
        model.filter = .text
        #expect(model.clips.map(\.text) == ["other", "note"])
        model.filter = .all
        #expect(model.clips.count == 4)
    }

    @Test func filterCombinesWithSearch() throws {
        let model = ClipListModel(store: try makeStore(["swift note", "https://swift.org", "https://apple.com"]))
        model.query = "swift"
        model.filter = .links
        #expect(model.clips.map(\.text) == ["https://swift.org"])
    }

    @Test func changingFilterResetsSelectionToTop() throws {
        let model = ClipListModel(store: try makeStore(["a", "https://x.com", "b"]))
        model.moveSelection(by: 2)
        model.filter = .text
        #expect(model.selectedIndex == 0)
    }

    @Test func cycleFilterGoesAllTextLinksImagesAll() throws {
        let model = ClipListModel(store: try makeStore(["a"]))
        #expect(model.filter == .all)
        model.cycleFilter()
        #expect(model.filter == .text)
        model.cycleFilter()
        #expect(model.filter == .links)
        model.cycleFilter()
        #expect(model.filter == .images)
        model.cycleFilter()
        #expect(model.filter == .all)
    }

    @Test func refreshKeepsTheFilter() throws {
        let store = try makeStore(["a", "https://x.com"])
        let model = ClipListModel(store: store)
        model.filter = .links
        try store.insert(CapturedClip(text: "https://y.com", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 99)))
        model.refresh()
        #expect(model.clips.map(\.text) == ["https://y.com", "https://x.com"])
    }

    @Test func filteringToNothingGivesAnEmptyListWithSafeSelection() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        model.filter = .links
        #expect(model.clips.isEmpty)
        #expect(model.selectedClip == nil)
        #expect(model.selectedIndex == 0)
    }

    // MARK: Delete

    @Test func deleteSelectedRemovesTheClipFromTheListAndTheStore() throws {
        let store = try makeStore(["a", "b", "c"])        // list: c, b, a
        let model = ClipListModel(store: store)
        model.moveSelection(by: 1)                         // on "b"
        model.deleteSelected()
        #expect(model.clips.map(\.text) == ["c", "a"])
        #expect(ClipListModel(store: store).clips.map(\.text) == ["c", "a"])   // really gone from the database
    }

    @Test func afterDeletingTheNextClipTakesItsRow() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))
        model.moveSelection(by: 1)
        model.deleteSelected()
        #expect(model.selectedIndex == 1)
        #expect(model.selectedClip?.text == "a")
    }

    @Test func deletingTheLastRowMovesTheSelectionUp() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))
        model.moveSelection(by: 2)                         // on "a", the last row
        model.deleteSelected()
        #expect(model.selectedIndex == 1)
        #expect(model.selectedClip?.text == "b")
    }

    @Test func deletingTheOnlyClipLeavesAnEmptyList() throws {
        let model = ClipListModel(store: try makeStore(["only"]))
        model.deleteSelected()
        #expect(model.clips.isEmpty)
        #expect(model.selectedClip == nil)
        #expect(model.selectedIndex == 0)
    }

    @Test func deleteWithNoSelectionDoesNothing() throws {
        let store = try makeStore(["a"])
        let model = ClipListModel(store: store)
        model.query = "zzz"
        model.deleteSelected()
        model.query = ""
        #expect(model.clips.map(\.text) == ["a"])
    }

    @Test func deletingKeepsTheCurrentSearchAndFilter() throws {
        let model = ClipListModel(store: try makeStore(["x1", "other", "x2"]))   // list: x2, other, x1
        model.query = "x"
        model.deleteSelected()                             // removes x2
        #expect(model.query == "x")
        #expect(model.clips.map(\.text) == ["x1"])
    }

    @Test func pinnedClipsCanBeDeletedOnPurpose() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        model.togglePinSelected()                          // pins "b" (top row)
        #expect(model.selectedClip?.isPinned == true)
        model.deleteSelected()
        #expect(model.clips.map(\.text) == ["a"])
    }

    // MARK: Notice

    @Test func noticeStartsEmpty() throws {
        #expect(ClipListModel(store: try makeStore(["a"])).notice == nil)
    }

    @Test func noticeDisappearsWhenTheSelectionMoves() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        model.notice = "Ignoring Safari"
        model.moveSelection(by: 1)
        #expect(model.notice == nil)
    }

    @Test func noticeDisappearsWhenTheQueryChanges() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        model.notice = "Ignoring Safari"
        model.query = "a"
        #expect(model.notice == nil)
    }

    @Test func noticeDisappearsWhenTheFilterChanges() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        model.notice = "Ignoring Safari"
        model.cycleFilter()
        #expect(model.notice == nil)
    }

    @Test func aNewCopyDoesNotHideTheNotice() throws {
        let model = ClipListModel(store: try makeStore(["a"]))
        model.notice = "Ignoring Safari"
        model.refresh()
        #expect(model.notice == "Ignoring Safari")
    }

    // MARK: Paging and navigation

    private func makeBigStore(_ count: Int) throws -> ClipStore {
        try makeStore((0..<count).map { "clip \($0)" })
    }

    @Test func startsWithOnePage() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        #expect(model.clips.count == 100)
        #expect(model.hasMore == true)
    }

    @Test func movingNearTheEndLoadsTheNextPage() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        model.moveSelection(by: 90)
        #expect(model.clips.count == 200)
        #expect(model.selectedIndex == 90)
    }

    @Test func loadMoreStopsAtTheEnd() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        model.loadMore()
        model.loadMore()
        #expect(model.clips.count == 250)
        #expect(model.hasMore == false)
        model.loadMore()
        #expect(model.clips.count == 250)
        #expect(model.hasMore == false)
    }

    @Test func refreshKeepsLoadedPagesAndSelectedClip() throws {
        let store = try makeBigStore(250)
        let model = ClipListModel(store: store)
        model.loadMore()
        #expect(model.clips.count == 200)
        model.select(row: 150)
        let id = model.selectedClip?.id
        try store.insert(CapturedClip(text: "fresh", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 9999)))
        model.refresh()
        #expect(model.clips.count == 201)
        #expect(model.selectedClip?.id == id)
    }

    @Test func refreshKeepsTheSelectedClipWhenSeveralClipsArrived() throws {
        let store = try makeBigStore(250)
        let model = ClipListModel(store: store)
        model.loadMore()
        model.loadMore()         // everything is loaded now
        model.select(row: 249)   // last loaded row
        let id = model.selectedClip?.id
        for i in 0..<3 {
            try store.insert(CapturedClip(text: "fresh \(i)", sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 9000 + Double(i))))
        }
        model.refresh()
        #expect(model.selectedClip?.id == id)
        #expect(model.clips.count == 253)
        #expect(model.hasMore == false)
    }

    @Test func deleteKeepsLoadedPages() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        model.loadMore()
        model.select(row: 150)
        model.deleteSelected()
        #expect(model.clips.count >= 199)
    }

    @Test func queryChangeResetsPaging() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        model.loadMore()
        model.moveSelection(by: 150)
        model.query = "clip"
        #expect(model.clips.count <= 100)
        #expect(model.selectedIndex == 0)
        model.loadMore()
        model.filter = .text
        #expect(model.clips.count <= 100)
        #expect(model.selectedIndex == 0)
    }

    @Test func shortFirstPageMeansNoMore() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        model.query = "clip 24"
        #expect(model.hasMore == false)
    }

    @Test func reverseCycleGoesAllImagesLinksTextAll() throws {
        let model = ClipListModel(store: try makeStore(["a"]))
        model.cycleFilter(reverse: true)
        #expect(model.filter == .images)
        model.cycleFilter(reverse: true)
        #expect(model.filter == .links)
        model.cycleFilter(reverse: true)
        #expect(model.filter == .text)
        model.cycleFilter(reverse: true)
        #expect(model.filter == .all)
    }

    @Test func resetForShowClearsQueryFilterAndSelection() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        model.loadMore()
        model.query = "clip"
        model.filter = .text
        model.moveSelection(by: 5)
        model.notice = "Ignoring Safari"
        model.resetForShow()
        #expect(model.query == "")
        #expect(model.filter == .all)
        #expect(model.selectedIndex == 0)
        #expect(model.notice == nil)
        #expect(model.clips.count == 100)
        #expect(model.hasMore == true)
    }

    @Test func resetForShowHidesTheShortcutsOverlay() throws {
        let model = ClipListModel(store: try makeStore(["a"]))
        model.showsShortcuts = true
        model.resetForShow()
        #expect(model.showsShortcuts == false)
    }

    @Test func escapeClearsQueryFirstThenCloses() throws {
        let model = ClipListModel(store: try makeStore(["a", "b"]))
        model.query = "a"
        #expect(model.escape() == .clearedQuery)
        #expect(model.query == "")
        #expect(model.escape() == .close)
    }

    @Test func moveToStartAndEnd() throws {
        let model = ClipListModel(store: try makeBigStore(250))
        model.moveToEnd()
        #expect(model.selectedIndex == 99)
        #expect(model.clips.count == 200)   // hasMore, so the next page was requested
        model.moveToStart()
        #expect(model.selectedIndex == 0)
    }

    @Test func movePageClamps() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]))
        model.movePage(1, rowsPerPage: 8)
        #expect(model.selectedIndex == 8)
        model.movePage(1, rowsPerPage: 8)
        #expect(model.selectedIndex == 9)
        model.select(row: 3)
        model.movePage(-1, rowsPerPage: 8)
        #expect(model.selectedIndex == 0)
    }

    @Test func movesClearTheNotice() throws {
        let model = ClipListModel(store: try makeStore(["a", "b", "c"]))
        for move in [{ model.moveToEnd() }, { model.moveToStart() }, { model.movePage(1, rowsPerPage: 2) }] {
            model.notice = "x"
            move()
            #expect(model.notice == nil)
        }
    }

    // MARK: Row snippets (cached per clip and query)

    private var deepMatch: String { String(repeating: "filler words ", count: 200) + "zebra crossing" }

    @Test func rowSnippetIsComputedOncePerClipAndQuery() throws {
        let model = ClipListModel(store: try makeStore([deepMatch]))
        model.query = "zebra"
        let clip = try #require(model.selectedClip)
        let first = model.rowSnippet(for: clip)
        #expect(first != nil)
        // Row bodies ask again on every hover, arrow key and ⌘ press: those must hit the cache.
        for _ in 0..<5 { #expect(model.rowSnippet(for: clip) == first) }
        #expect(model.rowSnippetComputations == 1)
    }

    @Test func rowSnippetCacheIsClearedWhenTheQueryChanges() throws {
        let model = ClipListModel(store: try makeStore([deepMatch]))
        model.query = "zebra"
        let clip = try #require(model.selectedClip)
        #expect(model.rowSnippet(for: clip)?.text.contains("zebra") == true)
        model.query = "crossing"
        let again = try #require(model.selectedClip)
        let snippet = try #require(model.rowSnippet(for: again))
        #expect(snippet.highlights.map { String(snippet.text[$0]) } == ["crossing"])
        #expect(model.rowSnippetComputations == 2)
    }

    @Test func rowSnippetIsNilWithoutAQueryAndCostsNothing() throws {
        let model = ClipListModel(store: try makeStore([deepMatch]))
        let clip = try #require(model.selectedClip)
        #expect(model.rowSnippet(for: clip) == nil)
        #expect(model.rowSnippetComputations == 0)
    }
}
