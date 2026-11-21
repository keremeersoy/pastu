import Foundation

/// Abstraction over the system pasteboard so the monitor is testable.
@MainActor
public protocol ClipboardSource: AnyObject {
    var changeCount: Int { get }
    /// With `includingText: false` only metadata (types, source app) is read, never the content.
    func snapshot(includingText: Bool) -> PasteboardSnapshot
    /// Replaces the pasteboard contents with plain text.
    func write(text: String)
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
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        // Common modes: the default mode alone stops firing while a menu is open or a drag is tracked,
        // and copies made at that moment would be missed.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Puts text on the pasteboard without Pastu capturing its own write
    /// (otherwise every paste from the panel would be recorded as a new copy).
    public func copyToPasteboard(_ text: String) {
        source.write(text: text)
        lastChangeCount = source.changeCount
    }

    public func poll() {
        let count = source.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // Look at metadata first: never read the content of concealed/transient/ignored-app copies.
        guard filter.shouldReadContent(of: source.snapshot(includingText: false)) else { return }
        let snapshot = source.snapshot(includingText: true)
        guard filter.decision(for: snapshot) == .record, let text = snapshot.text else { return }
        onCapture(CapturedClip(
            text: text,
            sourceBundleIdentifier: snapshot.sourceBundleIdentifier,
            date: Date()
        ))
    }
}
