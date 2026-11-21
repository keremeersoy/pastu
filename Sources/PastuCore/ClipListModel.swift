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
            reload()
        }
    }

    /// Restricts the list to text or links. Changing it moves the selection back to the top.
    public var filter = ClipFilter.all {
        didSet {
            guard filter != oldValue else { return }
            notice = nil
            selectedIndex = 0
            reload()
        }
    }

    /// A short message for the panel footer ("Ignoring Safari"). It disappears as soon as the user moves on:
    /// when the selection moves or the query or filter changes.
    public var notice: String?

    @ObservationIgnored private let store: ClipStore
    @ObservationIgnored private let limit: Int

    public init(store: ClipStore, limit: Int = 50) {
        self.store = store
        self.limit = limit
        reload()
    }

    public var selectedClip: StoredClip? {
        clips.indices.contains(selectedIndex) ? clips[selectedIndex] : nil
    }

    /// Re-runs the current search (e.g. after a new copy) and keeps the selection in range.
    public func refresh() {
        reload()
    }

    /// All, then Text, then Links, then back to All.
    public func cycleFilter() {
        filter = filter.next
    }

    /// Jumps to a row (used by ⌘1-9). Returns false, leaving the selection alone, when the row does not exist.
    @discardableResult
    public func select(row: Int) -> Bool {
        guard clips.indices.contains(row) else { return false }
        selectedIndex = row
        return true
    }

    /// Pins or unpins the selected clip. Pinned clips move to the top; the selection follows the clip.
    public func togglePinSelected() {
        guard let clip = selectedClip else { return }
        try? store.setPinned(id: clip.id, !clip.isPinned)
        reload()
        if let index = clips.firstIndex(where: { $0.id == clip.id }) { selectedIndex = index }
    }

    /// Deletes the selected clip from the history (pinned ones too: deleting is an explicit act).
    /// The next clip takes its row, or the selection moves up when the last row was deleted.
    public func deleteSelected() {
        guard let clip = selectedClip else { return }
        try? store.delete(id: clip.id)
        reload()   // clamps the selection into range
    }

    public func moveSelection(by delta: Int) {
        notice = nil
        guard !clips.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), clips.count - 1)
    }

    private func reload() {
        // A failing query shows an empty list instead of crashing the panel.
        clips = (try? store.search(query, limit: limit, kind: filter.kind)) ?? []
        selectedIndex = clips.isEmpty ? 0 : min(selectedIndex, clips.count - 1)
    }
}
