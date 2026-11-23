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
            guard query != oldValue, !isResetting else { return }
            notice = nil
            selectedIndex = 0
            reload(limit: pageSize)
        }
    }

    /// Restricts the list to text or links. Changing it moves the selection back to the top.
    public var filter = ClipFilter.all {
        didSet {
            guard filter != oldValue, !isResetting else { return }
            notice = nil
            selectedIndex = 0
            reload(limit: pageSize)
        }
    }

    /// A short message for the panel footer ("Ignoring Safari"). It disappears as soon as the user moves on:
    /// when the selection moves or the query or filter changes.
    public var notice: String?

    /// Whether the keyboard shortcuts overlay is open (⌘/). Lives here so the panel's Esc handling can close it first.
    public var showsShortcuts = false

    /// True while the last fetched page was full, so there may be more rows to load.
    public private(set) var hasMore = false

    public enum EscapeOutcome: Sendable, Equatable { case clearedQuery, close }

    @ObservationIgnored private let store: ClipStore
    @ObservationIgnored private let pageSize: Int
    /// Start loading the next page when the selection is this close to the end of the loaded rows.
    @ObservationIgnored private let prefetchDistance = 10
    /// True while `resetForShow` clears the query and filter, so their observers do not reload on their own.
    @ObservationIgnored private var isResetting = false

    /// Row snippets for `snippetCacheQuery`, by clip id. Finding the match scans the whole clip, and row views are
    /// rebuilt on every hover, arrow key and ⌘ press, so each clip is searched once per query. Not observed:
    /// filling it while a row draws must not invalidate the view.
    @ObservationIgnored private var snippetCache: [Int64: SearchHighlighter.Snippet?] = [:]
    @ObservationIgnored private var snippetCacheQuery = ""
    /// How many snippets were actually computed; lets tests prove the cache is used.
    @ObservationIgnored private(set) var rowSnippetComputations = 0
    /// Which clips have a cached snippet; lets tests prove that removed clips are forgotten.
    var cachedSnippetIDs: Set<Int64> { Set(snippetCache.keys) }
    /// How many times the list was reloaded from the store; lets tests prove a reset reloads once.
    @ObservationIgnored private(set) var reloads = 0

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

    /// Forgets every cached row snippet. A snippet is clip text, so it must not outlive Clear History.
    /// Clips deleted in the panel can no longer be restored either: they are clip text as well.
    public func purgeSnippets() {
        snippetCache = [:]
        snippetCacheQuery = ""
        deletedClips = []
    }

    /// Forgets one clip's snippet, because the clip was removed.
    public func forgetSnippet(of clipID: Int64) {
        snippetCache[clipID] = nil
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
        showsShortcuts = false
        purgeSnippets()
        // The query and filter observers would each reload; hold them back and reload once at the end, which also
        // covers a no-change reset (it still drops extra pages and the selection).
        isResetting = true
        query = ""
        filter = .all
        isResetting = false
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
        // Kept in memory only, for ⌘Z while the panel stays open; `purgeSnippets` drops it.
        if let snapshot = try? store.snapshot(id: clip.id) {
            deletedClips.append(snapshot)
            if deletedClips.count > Self.undoLimit { deletedClips.removeFirst() }
        }
        try? store.delete(id: clip.id)
        queue.remove(id: clip.id)
        forgetSnippet(of: clip.id)
        reloadLoaded()   // clamps the selection into range
    }

    /// Clips collected to be pasted one after another. Survives the panel closing: it is pasted afterwards.
    public let queue = PasteQueue()

    /// Adds the selected clip to the queue and moves on to the next row, so a run of clips can be collected quickly.
    public func addSelectedToQueue() {
        guard let clip = selectedClip else { return }
        let message: String
        if queue.add(clip) {
            moveSelection(by: 1)
            message = "Added to queue (\(queue.count))"
        } else if queue.isFull, queue.position(of: clip.id) == nil {
            message = "The queue is full (\(PasteQueue.limit))"
        } else {
            message = "Already in the queue"
        }
        notice = message
    }

    public func clearQueue() {
        guard !queue.isEmpty else { return }
        queue.clear()
        notice = "Queue cleared"
    }

    /// How many deletes ⌘Z can undo in one panel session.
    public static let undoLimit = 20

    /// Deleted clips, oldest first; restored last-in first-out. Not observed: the list reloads when one comes back.
    @ObservationIgnored private var deletedClips: [ClipSnapshot] = []
    public var canUndoDelete: Bool { !deletedClips.isEmpty }

    /// ⌘Z: brings back the clip deleted last and selects it. Returns false when there is nothing to restore.
    @discardableResult
    public func undoDelete() -> Bool {
        guard let snapshot = deletedClips.last, let id = try? store.restore(snapshot) else { return false }
        deletedClips.removeLast()
        reloadLoaded()
        if let index = clips.firstIndex(where: { $0.id == id }) { selectedIndex = index }
        notice = "Restored"
        return true
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
        reloads += 1
        // A failing query shows an empty list instead of crashing the panel.
        clips = (try? store.search(query, limit: limit, offset: 0, kind: filter.kind)) ?? []
        // A short page means the history is exhausted; the extra rows of a bigger reload count too.
        hasMore = clips.count == limit
        selectedIndex = clips.isEmpty ? 0 : min(selectedIndex, clips.count - 1)
    }
}
