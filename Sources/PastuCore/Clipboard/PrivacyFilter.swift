/// Decides whether a pasteboard snapshot may enter the history.
///
/// Password managers mark sensitive copies with the community-standard
/// types from nspasteboard.org; those must never be stored.
public struct PrivacyFilter: Sendable {
    /// Why a copy was not recorded. Kept distinct so tests can prove each privacy rule on its own.
    public enum SkipReason: Equatable, Sendable {
        case concealed
        case transient
        case ignoredApp
        case empty
        case tooLarge
    }

    /// The verdict for one pasteboard change.
    public enum Decision: Equatable, Sendable {
        case record
        case skip(SkipReason)
    }

    /// Marker types from nspasteboard.org: password managers set them on secrets and one-off values.
    public static let concealedType = "org.nspasteboard.ConcealedType"
    public static let transientType = "org.nspasteboard.TransientType"

    /// Copies larger than this (UTF-8 bytes) are not recorded: one huge copy must not bloat the database and search index.
    public static let defaultMaxTextBytes = 1_000_000

    /// Pictures larger than this (PNG bytes) are not recorded: a few big screenshots must not fill the history.
    public static let defaultMaxImageBytes = 10_000_000

    public var ignoredBundleIdentifiers: Set<String>
    public var maxTextBytes: Int
    public var maxImageBytes: Int

    public init(
        ignoredBundleIdentifiers: Set<String> = [],
        maxTextBytes: Int = PrivacyFilter.defaultMaxTextBytes,
        maxImageBytes: Int = PrivacyFilter.defaultMaxImageBytes
    ) {
        self.ignoredBundleIdentifiers = ignoredBundleIdentifiers
        self.maxTextBytes = maxTextBytes
        self.maxImageBytes = maxImageBytes
    }

    /// Whether the content of this item may be read at all. Decided from metadata only,
    /// so sensitive content never even enters Pastu's memory.
    public func shouldReadContent(of snapshot: PasteboardSnapshot) -> Bool {
        metadataSkipReason(for: snapshot) == nil
    }

    /// The final verdict, once the content has been read: privacy markers, emptiness and size limits.
    public func decision(for snapshot: PasteboardSnapshot) -> Decision {
        if let reason = metadataSkipReason(for: snapshot) { return .skip(reason) }
        // Text wins when a copy carries both text and a picture (browsers, office apps), so the clip stays searchable.
        if let text = snapshot.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.utf8.count > maxTextBytes ? .skip(.tooLarge) : .record
        }
        if let png = snapshot.imagePNG, !png.isEmpty {
            return png.count > maxImageBytes ? .skip(.tooLarge) : .record
        }
        return .skip(.empty)
    }

    private func metadataSkipReason(for snapshot: PasteboardSnapshot) -> SkipReason? {
        if snapshot.types.contains(Self.concealedType) { return .concealed }
        if snapshot.types.contains(Self.transientType) { return .transient }
        if let app = snapshot.sourceBundleIdentifier, ignoredBundleIdentifiers.contains(app) {
            return .ignoredApp
        }
        return nil
    }
}
