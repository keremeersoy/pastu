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
            selectedIndex = 0
            reload()
        }
    }

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

    public func moveSelection(by delta: Int) {
        guard !clips.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), clips.count - 1)
    }

    private func reload() {
        // A failing query shows an empty list instead of crashing the panel.
        clips = (try? store.search(query, limit: limit)) ?? []
        selectedIndex = clips.isEmpty ? 0 : min(selectedIndex, clips.count - 1)
    }
}
