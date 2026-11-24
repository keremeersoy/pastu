import CryptoKit
import Foundation

/// Abstraction over the system pasteboard so the monitor is testable.
@MainActor
public protocol ClipboardSource: AnyObject {
    var changeCount: Int { get }
    /// With `includingContent: false` only metadata (types, source app) is read, never the content.
    func snapshot(includingContent: Bool) -> PasteboardSnapshot
    /// Replaces the pasteboard contents with text, plus its RTF/HTML formatting when given.
    func write(text: String, rtf: Data?, html: Data?)
    /// Replaces the pasteboard contents with picture bytes.
    func write(imagePNG: Data)
    /// Replaces the pasteboard contents with files, the way copying them in Finder would.
    func write(files: [URL])
}

extension ClipboardSource {
    /// Replaces the pasteboard contents with plain text.
    func write(text: String) { write(text: text, rtf: nil, html: nil) }
}

/// A copy that passed the privacy filter.
public struct CapturedClip: Equatable, Sendable {
    /// For text clips the copied text. For image clips a stable key made from the image's content
    /// (`[image] <hash>`), so the same picture copied twice merges and search can find images.
    public let text: String
    public let sourceBundleIdentifier: String?
    public let date: Date
    /// PNG data when the clip is an image, otherwise nil.
    public var imagePNG: Data? = nil
    /// The copied text's RTF and HTML flavours when the source app offered them, otherwise nil.
    public var rtf: Data? = nil
    public var html: Data? = nil
    /// The paths of the files copied in Finder, otherwise nil. The clip then stands for those files, not for text.
    public var files: [String]? = nil

    /// A file clip, keyed by a hash of the full paths so the same files copied again merge into one row, while the same
    /// file names in two different folders stay two clips. The key never shows a path: the panel shows the names.
    static func files(paths: [String], sourceBundleIdentifier: String? = nil, date: Date = Date()) -> CapturedClip {
        let digest = SHA256.hash(data: Data(paths.joined(separator: "\n").utf8)).prefix(8)
            .map { String(format: "%02x", $0) }.joined()
        return CapturedClip(
            text: "[files] \(digest)", sourceBundleIdentifier: sourceBundleIdentifier, date: date, files: paths
        )
    }

    /// An image clip, keyed by a hash of its bytes so the same picture copied twice merges into one row.
    static func image(png: Data, sourceBundleIdentifier: String? = nil, date: Date = Date()) -> CapturedClip {
        let digest = SHA256.hash(data: png).prefix(8).map { String(format: "%02x", $0) }.joined()
        return CapturedClip(
            text: "[image] \(digest)", sourceBundleIdentifier: sourceBundleIdentifier, date: date, imagePNG: png
        )
    }
}

/// Polls the pasteboard's changeCount (macOS has no change notification)
/// and reports new, filter-approved copies.
@MainActor
public final class ClipboardMonitor {
    private let source: ClipboardSource
    /// Replaceable at runtime, e.g. when the user adds an app to the ignore list.
    public var filter: PrivacyFilter
    private let recording: RecordingState
    private let onCapture: (CapturedClip) -> Void
    private var lastChangeCount: Int
    private var timer: Timer?

    /// Content already on the pasteboard at creation time is deliberately not captured.
    public init(
        source: ClipboardSource,
        filter: PrivacyFilter,
        recording: RecordingState = RecordingState(),
        onCapture: @escaping (CapturedClip) -> Void
    ) {
        self.source = source
        self.filter = filter
        self.recording = recording
        self.onCapture = onCapture
        self.lastChangeCount = source.changeCount
    }

    /// Polls `changeCount` on a timer. macOS has no clipboard-change notification, so polling is the only option;
    /// reading an integer twice a second costs next to nothing.
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

    /// Stops polling. Safe to call when not started.
    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Each stored formatting flavour (RTF, HTML) may be at most this big. A page copied from a browser can carry
    /// megabytes of markup; the text is kept, the formatting that large is not.
    public static let maxFormattingBytes = 2 * 1024 * 1024

    private static func withinFormattingLimit(_ data: Data?) -> Data? {
        guard let data, data.count <= maxFormattingBytes else { return nil }
        return data
    }

    /// Puts text on the pasteboard without Pastu capturing its own write
    /// (otherwise every paste from the panel would be recorded as a new copy).
    public func copyToPasteboard(_ text: String, rtf: Data? = nil, html: Data? = nil) {
        source.write(text: text, rtf: rtf, html: html)
        lastChangeCount = source.changeCount
    }

    /// Puts a picture on the pasteboard without capturing our own write.
    public func copyToPasteboard(imagePNG: Data) {
        source.write(imagePNG: imagePNG)
        lastChangeCount = source.changeCount
    }

    /// Puts files on the pasteboard, the way copying them in Finder would, without capturing our own write.
    public func copyToPasteboard(files: [URL]) {
        source.write(files: files)
        lastChangeCount = source.changeCount
    }

    /// Checks the pasteboard once. Public so tests can drive the monitor without a timer.
    public func poll() {
        let count = source.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // Paused: the change is consumed (so it is not captured after resuming) but never looked at.
        guard !recording.isPaused else { return }

        // Look at metadata first: never read the content of concealed/transient/ignored-app copies.
        guard filter.shouldReadContent(of: source.snapshot(includingContent: false)) else { return }
        let snapshot = source.snapshot(includingContent: true)
        guard filter.decision(for: snapshot) == .record else { return }

        if !snapshot.fileURLs.isEmpty {
            // Finder offers the file names as text too; the files are the copy, the names are not.
            onCapture(.files(
                paths: snapshot.fileURLs.map(\.path), sourceBundleIdentifier: snapshot.sourceBundleIdentifier, date: Date()
            ))
        } else if let text = snapshot.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onCapture(CapturedClip(
                text: text, sourceBundleIdentifier: snapshot.sourceBundleIdentifier, date: Date(),
                rtf: Self.withinFormattingLimit(snapshot.rtf), html: Self.withinFormattingLimit(snapshot.html)
            ))
        } else if let png = snapshot.imagePNG {
            onCapture(.image(png: png, sourceBundleIdentifier: snapshot.sourceBundleIdentifier, date: Date()))
        }
    }
}
