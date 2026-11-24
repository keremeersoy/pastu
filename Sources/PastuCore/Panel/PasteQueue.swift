import Foundation
import Observation

/// Clips collected in the panel to be pasted one after another, in the order they were added.
/// Kept in memory only: it holds clip text, and it is dropped when the history is cleared or a clip is deleted.
@MainActor @Observable
public final class PasteQueue {
    public static let limit = 20

    public private(set) var clips: [StoredClip] = []

    public init() {}

    public var count: Int { clips.count }
    public var isEmpty: Bool { clips.isEmpty }
    public var isFull: Bool { clips.count >= Self.limit }

    /// 1-based place in the queue, or nil when the clip is not queued.
    public func position(of clipID: Int64) -> Int? {
        clips.firstIndex { $0.id == clipID }.map { $0 + 1 }
    }

    /// False when the clip is already queued or the queue is full.
    @discardableResult
    public func add(_ clip: StoredClip) -> Bool {
        guard !isFull, position(of: clip.id) == nil else { return false }
        clips.append(clip)
        return true
    }

    public func remove(id: Int64) {
        clips.removeAll { $0.id == id }
    }

    public func clear() {
        clips = []
    }

    /// What to paste, in order: each clip with the text that follows it. The last clip and pictures get none.
    public func plan(separator: QueueSeparator) -> [(clip: StoredClip, suffix: String)] {
        clips.enumerated().map { index, clip in
            (clip, index < clips.count - 1 && clip.kind != .image ? separator.text : "")
        }
    }
}
