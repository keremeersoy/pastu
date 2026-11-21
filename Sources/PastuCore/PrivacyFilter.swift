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
    }

    public enum Decision: Equatable, Sendable {
        case record
        case skip(SkipReason)
    }

    public static let concealedType = "org.nspasteboard.ConcealedType"
    public static let transientType = "org.nspasteboard.TransientType"

    public var ignoredBundleIdentifiers: Set<String>

    public init(ignoredBundleIdentifiers: Set<String> = []) {
        self.ignoredBundleIdentifiers = ignoredBundleIdentifiers
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
