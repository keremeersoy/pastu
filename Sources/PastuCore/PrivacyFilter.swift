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

    public func decision(for snapshot: PasteboardSnapshot) -> Decision {
        if snapshot.types.contains(Self.concealedType) { return .skip(.concealed) }
        if snapshot.types.contains(Self.transientType) { return .skip(.transient) }
        if let app = snapshot.sourceBundleIdentifier, ignoredBundleIdentifiers.contains(app) {
            return .skip(.ignoredApp)
        }
        guard let text = snapshot.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .skip(.empty)
        }
        return .record
    }
}
