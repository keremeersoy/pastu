import Foundation

/// Whether Pastu is recording the clipboard. While paused, copies are neither read nor saved.
/// Optionally persisted in a `SettingsStore`, so a pause survives a relaunch.
@MainActor
public final class RecordingState {
    private let store: SettingsStore?
    private static let key = "recordingPaused"

    public var isPaused: Bool {
        didSet { store?.set(isPaused, forKey: Self.key) }
    }

    /// - Parameter store: where to persist the flag, or `nil` to keep it only in this object.
    public init(store: SettingsStore? = nil) {
        self.store = store
        self.isPaused = store?.bool(forKey: Self.key) ?? false
    }

    public func toggle() {
        isPaused.toggle()
    }
}
