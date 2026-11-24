import AppKit
import PastuCore

/// "Show in Finder" for file clips: selects the files that are still there in a Finder window.
@MainActor
struct FinderReveal {
    /// What the row menu uses; tests build their own with a recording closure.
    static var shared = FinderReveal()

    private let reveal: @MainActor ([URL]) -> Void

    init(_ reveal: @escaping @MainActor ([URL]) -> Void = { NSWorkspace.shared.activateFileViewerSelecting($0) }) {
        self.reveal = reveal
    }

    /// False for other kinds of clip, and when every file is gone (there is nothing to select).
    @discardableResult
    func show(_ clip: StoredClip) -> Bool {
        guard clip.kind == .file else { return false }
        let existing = clip.files.filter { FileManager.default.fileExists(atPath: $0) }.map { URL(fileURLWithPath: $0) }
        guard !existing.isEmpty else { return false }
        reveal(existing)
        return true
    }
}
