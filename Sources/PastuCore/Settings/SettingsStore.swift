import Foundation

/// The few key-value operations Pastu needs to remember settings between launches.
///
/// The app uses `UserDefaults`; tests use `InMemorySettings`. Tests must not write to `UserDefaults`:
/// every suite leaves a `.plist` in `~/Library/Preferences`, and removing it races with the preferences daemon.
public protocol SettingsStore: AnyObject {
    func bool(forKey key: String) -> Bool
    /// True when the key was never written; lets a setting default to on.
    func isUnset(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func stringArray(forKey key: String) -> [String]?
    func set(_ value: Any?, forKey key: String)
}

/// `UserDefaults` already has these methods, apart from `isUnset`.
extension UserDefaults: SettingsStore {
    public func isUnset(forKey key: String) -> Bool { object(forKey: key) == nil }
}

/// A settings store that lives in memory only. Sharing one instance between two objects simulates a relaunch.
public final class InMemorySettings: SettingsStore {
    private var values: [String: Any] = [:]

    public init() {}

    public func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    public func isUnset(forKey key: String) -> Bool { values[key] == nil }
    public func string(forKey key: String) -> String? { values[key] as? String }
    public func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    public func set(_ value: Any?, forKey key: String) { values[key] = value }
}

/// Every key Pastu stores in its `SettingsStore`, in one place. The strings are part of the on-disk format:
/// changing one silently drops that setting for existing users (pinned by `DefaultsKeysTests`).
enum DefaultsKeys {
    static let recordingPaused = "recordingPaused"
    static let ignoredApps = "ignoredApps"
    static let panelAppearance = "panelAppearance"
    static let panelMaterial = "panelMaterial"
    static let hotKey = "hotKey"
    static let onboardingDone = "onboardingDone"
    static let queueSeparator = "queueSeparator"
    static let recognizeTextInPictures = "recognizeTextInPictures"
    static let retentionCount = "retentionCount"
    static let retentionAgeDays = "retentionAgeDays"
    static let retentionSizeMB = "retentionSizeMB"
}
