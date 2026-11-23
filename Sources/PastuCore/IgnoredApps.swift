import Foundation
import Observation

/// Apps whose copies Pastu must never record or even read (password managers, banking apps, …).
/// Persisted in a `SettingsStore`.
@MainActor @Observable
public final class IgnoredApps {
    @ObservationIgnored private let store: SettingsStore?
    private static let key = DefaultsKeys.ignoredApps

    /// Called with the new set after every real change (not for no-ops).
    @ObservationIgnored public var onChange: ((Set<String>) -> Void)?
    public private(set) var bundleIdentifiers: Set<String>
    public var sortedIdentifiers: [String] { bundleIdentifiers.sorted() }

    /// - Parameter store: where to persist the list, or `nil` to keep it only in this object.
    public init(store: SettingsStore? = nil) {
        self.store = store
        self.bundleIdentifiers = Set(store?.stringArray(forKey: Self.key) ?? [])
    }

    /// Returns true when the app was newly added; blank identifiers are rejected.
    @discardableResult
    public func add(_ bundleIdentifier: String) -> Bool {
        let id = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, bundleIdentifiers.insert(id).inserted else { return false }
        changed()
        return true
    }

    /// Starts recording that app again from the next copy. Unknown identifiers are a no-op.
    public func remove(_ bundleIdentifier: String) {
        guard bundleIdentifiers.remove(bundleIdentifier) != nil else { return }
        changed()
    }

    private func changed() {
        store?.set(sortedIdentifiers, forKey: Self.key)
        onChange?(bundleIdentifiers)
    }
}
