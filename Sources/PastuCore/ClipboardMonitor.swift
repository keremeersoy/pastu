import Foundation

/// Abstraction over the system pasteboard so the monitor is testable.
@MainActor
public protocol ClipboardSource: AnyObject {
    var changeCount: Int { get }
    func snapshot() -> PasteboardSnapshot
}

/// A copy that passed the privacy filter.
public struct CapturedClip: Equatable, Sendable {
    public let text: String
    public let sourceBundleIdentifier: String?
    public let date: Date
}

/// Polls the pasteboard's changeCount (macOS has no change notification)
/// and reports new, filter-approved copies.
@MainActor
public final class ClipboardMonitor {
    private let source: ClipboardSource
    private let filter: PrivacyFilter
    private let onCapture: (CapturedClip) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?

    /// Content already on the pasteboard at creation time is deliberately not captured.
    public init(
        source: ClipboardSource,
        filter: PrivacyFilter,
        onCapture: @escaping (CapturedClip) -> Void
    ) {
        self.source = source
        self.filter = filter
        self.onCapture = onCapture
        self.lastChangeCount = source.changeCount
    }

    public func start(interval: TimeInterval = 0.5) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func poll() {
        let count = source.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        let snapshot = source.snapshot()
        guard filter.decision(for: snapshot) == .record, let text = snapshot.text else { return }
        onCapture(CapturedClip(
            text: text,
            sourceBundleIdentifier: snapshot.sourceBundleIdentifier,
            date: Date()
        ))
    }
}
