/// Decides whether a pasteboard snapshot may enter the history.
///
/// Password managers mark sensitive copies with the community-standard
/// types from nspasteboard.org; those must never be stored.
public struct PrivacyFilter: Sendable {
    public enum SkipReason: Equatable, Sendable {
        case concealed
        case transient
        case ignoredApp
        case empty
        case tooLarge
    }

    public enum Decision: Equatable, Sendable {
        case record
        case skip(SkipReason)
    }

    public static let concealedType = "org.nspasteboard.ConcealedType"
    public static let transientType = "org.nspasteboard.TransientType"

    /// Copies larger than this (UTF-8 bytes) are not recorded: one huge copy must not bloat the database and search index.
    public static let defaultMaxTextBytes = 1_000_000

    public var ignoredBundleIdentifiers: Set<String>
    public var maxTextBytes: Int

    public init(
        ignoredBundleIdentifiers: Set<String> = [],
        maxTextBytes: Int = PrivacyFilter.defaultMaxTextBytes
    ) {
        self.ignoredBundleIdentifiers = ignoredBundleIdentifiers
        self.maxTextBytes = maxTextBytes
    }

    /// Whether the content of this item may be read at all. Decided from metadata only,
    /// so sensitive content never even enters Pastu's memory.
    public func shouldReadContent(of snapshot: PasteboardSnapshot) -> Bool {
        metadataSkipReason(for: snapshot) == nil
    }

    public func decision(for snapshot: PasteboardSnapshot) -> Decision {
        if let reason = metadataSkipReason(for: snapshot) { return .skip(reason) }
        guard let text = snapshot.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .skip(.empty)
        }
        if text.utf8.count > maxTextBytes { return .skip(.tooLarge) }
        return .record
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
