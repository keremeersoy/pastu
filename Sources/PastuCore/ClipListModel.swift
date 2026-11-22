import Observation

/// Drives the panel's list: search query, results and keyboard selection.
@MainActor
@Observable
public final class ClipListModel {
    public private(set) var clips: [StoredClip] = []
    public private(set) var selectedIndex = 0

    /// Setting a new query re-runs the search and moves the selection back to the top.
    public var query = "" {
        didSet {
            guard query != oldValue else { return }
            notice = nil
            selectedIndex = 0
            reload(limit: pageSize)
        }
    }

    /// Restricts the list to text or links. Changing it moves the selection back to the top.
    public var filter = ClipFilter.all {
        didSet {
            guard filter != oldValue else { return }
            notice = nil
            selectedIndex = 0
            reload(limit: pageSize)
        }
    }

    /// A short message for the panel footer ("Ignoring Safari"). It disappears as soon as the user moves on:
    /// when the selection moves or the query or filter changes.
    public var notice: String?

    /// True while the last fetched page was full, so there may be more rows to load.
    public private(set) var hasMore = false

    public enum EscapeOutcome: Sendable, Equatable { case clearedQuery, close }

    @ObservationIgnored private let store: ClipStore
    @ObservationIgnored private let pageSize: Int
    /// Start loading the next page when the selection is this close to the end of the loaded rows.
    @ObservationIgnored private let prefetchDistance = 10

    /// Row snippets for `snippetCacheQuery`, by clip id. Finding the match scans the whole clip, and row views are
    /// rebuilt on every hover, arrow key and ⌘ press, so each clip is searched once per query. Not observed:
    /// filling it while a row draws must not invalidate the view.
    @ObservationIgnored private var snippetCache: [Int64: SearchHighlighter.Snippet?] = [:]
    @ObservationIgnored private var snippetCacheQuery = ""
    /// How many snippets were actually computed; lets tests prove the cache is used.
    @ObservationIgnored private(set) var rowSnippetComputations = 0

    public init(store: ClipStore, pageSize: Int = 100) {
        self.store = store
        self.pageSize = pageSize
        reload(limit: pageSize)
    }

    /// The snippet the clip's row shows instead of "App · time" for the current query (see
    /// `SearchHighlighter.rowSnippet`); nil for pictures, without a query, or when the title shows the match.
    public func rowSnippet(for clip: StoredClip) -> SearchHighlighter.Snippet? {
        guard clip.kind != .image, !SearchHighlighter.terms(of: query).isEmpty else { return nil }
        if snippetCacheQuery != query {
            snippetCache = [:]
            snippetCacheQuery = query
        }
        if let cached = snippetCache[clip.id] { return cached }
        rowSnippetComputations += 1
        let snippet = SearchHighlighter.rowSnippet(of: query, title: ClipFormatting.rowTitle(clip.text), text: clip.text)
        snippetCache[clip.id] = snippet
        return snippet
    }

    public var selectedClip: StoredClip? {
        clips.indices.contains(selectedIndex) ? clips[selectedIndex] : nil
    }

    /// Re-runs the current search (e.g. after a new copy) over every row loaded so far, so a refresh
    /// never throws the user back to the first page. The selection stays on the same clip when it is still there.
    public func refresh() {
        let id = selectedClip?.id
        let lastLoadedID = clips.last?.id
        let loaded = max(clips.count, pageSize)
        // Fetch a whole extra page so any number of new copies since the last refresh still leaves the
        // previously loaded rows (and the selected clip) inside the result.
        let limit = loaded + pageSize
        let fetched = (try? store.search(query, limit: limit, offset: 0, kind: filter.kind)) ?? []
        // Keep at least what was loaded, extended to include the selected clip and the old last row, so a
        // refresh never drops either. Growth is bounded by the number of new clips.
        var keep = min(loaded, fetched.count)
        for target in [id, lastLoadedID] {
            if let target, let index = fetched.firstIndex(where: { $0.id == target }) { keep = max(keep, index + 1) }
        }
        clips = Array(fetched.prefix(keep))
        // More may exist when the fetch was full or we trimmed rows we did fetch.
        hasMore = fetched.count == limit || fetched.count > keep
        if let id, let index = clips.firstIndex(where: { $0.id == id }) {
            selectedIndex = index
        } else {
            selectedIndex = clips.isEmpty ? 0 : min(selectedIndex, clips.count - 1)
        }
    }

    /// Appends the next page for the current query and filter. The selection does not move.
    public func loadMore() {
        guard hasMore else { return }
        let page = (try? store.search(query, limit: pageSize, offset: clips.count, kind: filter.kind)) ?? []
        clips.append(contentsOf: page)
        hasMore = page.count == pageSize
    }

    /// All, then Text, then Links, then Images, then back to All (reversed for Shift-Tab).
    public func cycleFilter(reverse: Bool = false) {
        filter = reverse ? filter.previous : filter.next
    }

    /// Back to a fresh state each time the panel opens: no query, no filter, first page, top row.
    public func resetForShow() {
        notice = nil
        // The observers below would reload on their own; do it once explicitly so a no-change reset
        // still drops extra pages and the selection.
        query = ""
        filter = .all
        selectedIndex = 0
        reload(limit: pageSize)
    }

    /// Esc: the first press clears a non-empty query, the next one closes the panel.
    public func escape() -> EscapeOutcome {
        guard !query.isEmpty else { return .close }
        query = ""
        return .clearedQuery
    }

    /// Jumps to a row (used by ⌘1-9). Returns false, leaving the selection alone, when the row does not exist.
    @discardableResult
    public func select(row: Int) -> Bool {
        guard clips.indices.contains(row) else { return false }
        selectedIndex = row
        prefetchIfNearEnd()
        return true
    }

    /// Pins or unpins the selected clip. Pinned clips move to the top; the selection follows the clip.
    public func togglePinSelected() {
        guard let clip = selectedClip else { return }
        try? store.setPinned(id: clip.id, !clip.isPinned)
        reloadLoaded()
        if let index = clips.firstIndex(where: { $0.id == clip.id }) { selectedIndex = index }
    }

    /// Deletes the selected clip from the history (pinned ones too: deleting is an explicit act).
    /// The next clip takes its row, or the selection moves up when the last row was deleted.
    public func deleteSelected() {
        guard let clip = selectedClip else { return }
        try? store.delete(id: clip.id)
        reloadLoaded()   // clamps the selection into range
    }

    /// Moves the selection with the arrow keys, clamped to the list (no wrap-around). Clears any notice.
    public func moveSelection(by delta: Int) {
        notice = nil
        guard !clips.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), clips.count - 1)
        prefetchIfNearEnd()
    }

    /// Home: first row.
    public func moveToStart() {
        notice = nil
        selectedIndex = 0
    }

    /// End: last loaded row; more rows are requested when the history continues.
    public func moveToEnd() {
        notice = nil
        guard !clips.isEmpty else { return }
        selectedIndex = clips.count - 1
        loadMore()
    }

    /// Page Up / Page Down: moves by a screenful of rows, clamped like `moveSelection`.
    public func movePage(_ direction: Int, rowsPerPage: Int) {
        moveSelection(by: direction * rowsPerPage)
    }

    private func prefetchIfNearEnd() {
        if hasMore, selectedIndex >= clips.count - prefetchDistance { loadMore() }
    }

    private func reloadLoaded() {
        reload(limit: max(clips.count, pageSize))
    }

    private func reload(limit: Int) {
        // A failing query shows an empty list instead of crashing the panel.
        clips = (try? store.search(query, limit: limit, offset: 0, kind: filter.kind)) ?? []
        // A short page means the history is exhausted; the extra rows of a bigger reload count too.
        hasMore = clips.count == limit
        selectedIndex = clips.isEmpty ? 0 : min(selectedIndex, clips.count - 1)
    }
}
