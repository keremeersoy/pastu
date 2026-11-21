import Foundation

/// Apps whose copies Pastu must never record or even read (password managers, banking apps, …).
/// Persisted in `UserDefaults`.
@MainActor
public final class IgnoredApps {
    private let defaults: UserDefaults?
    private static let key = "ignoredApps"

    /// Called with the new set after every real change (not for no-ops).
    public var onChange: ((Set<String>) -> Void)?
    public private(set) var bundleIdentifiers: Set<String>
    public var sortedIdentifiers: [String] { bundleIdentifiers.sorted() }

    /// - Parameter defaults: where to persist the list, or `nil` to keep it in memory only (tests).
    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        self.bundleIdentifiers = Set(defaults?.stringArray(forKey: Self.key) ?? [])
    }

    /// Returns true when the app was newly added; blank identifiers are rejected.
    @discardableResult
    public func add(_ bundleIdentifier: String) -> Bool {
        let id = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, bundleIdentifiers.insert(id).inserted else { return false }
        changed()
        return true
    }

    public func remove(_ bundleIdentifier: String) {
        guard bundleIdentifiers.remove(bundleIdentifier) != nil else { return }
        changed()
    }

    private func changed() {
        defaults?.set(sortedIdentifiers, forKey: Self.key)
        onChange?(bundleIdentifiers)
    }
}
