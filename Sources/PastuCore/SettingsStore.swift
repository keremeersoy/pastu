import Foundation

/// The few key-value operations Pastu needs to remember settings between launches.
///
/// The app uses `UserDefaults`; tests use `InMemorySettings`. Tests must not write to `UserDefaults`:
/// every suite leaves a `.plist` in `~/Library/Preferences`, and removing it races with the preferences daemon.
public protocol SettingsStore: AnyObject {
    func bool(forKey key: String) -> Bool
    func stringArray(forKey key: String) -> [String]?
    func set(_ value: Any?, forKey key: String)
}

/// `UserDefaults` already has exactly these methods.
extension UserDefaults: SettingsStore {}

/// A settings store that lives in memory only. Sharing one instance between two objects simulates a relaunch.
public final class InMemorySettings: SettingsStore {
    private var values: [String: Any] = [:]

    public init() {}

    public func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    public func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    public func set(_ value: Any?, forKey key: String) { values[key] = value }
}
