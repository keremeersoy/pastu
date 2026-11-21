import Foundation

/// Whether Pastu is recording the clipboard. While paused, copies are neither read nor saved.
/// Optionally persisted in `UserDefaults`, so a pause survives a relaunch.
@MainActor
public final class RecordingState {
    private let defaults: UserDefaults?
    private static let key = "recordingPaused"

    public var isPaused: Bool {
        didSet { defaults?.set(isPaused, forKey: Self.key) }
    }

    /// - Parameter defaults: where to persist the flag, or `nil` to keep it in memory only (tests).
    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        self.isPaused = defaults?.bool(forKey: Self.key) ?? false
    }

    public func toggle() {
        isPaused.toggle()
    }
}
