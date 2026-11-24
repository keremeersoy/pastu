import Foundation
import Observation

/// "Find text in pictures": on unless the user switched it off. Persisted in a `SettingsStore`.
@MainActor @Observable
public final class PictureTextSettings {
    @ObservationIgnored private let store: SettingsStore?

    public var isEnabled: Bool {
        didSet { store?.set(isEnabled, forKey: DefaultsKeys.recognizeTextInPictures) }
    }

    public init(store: SettingsStore? = nil) {
        self.store = store
        isEnabled = store.map { $0.isUnset(forKey: DefaultsKeys.recognizeTextInPictures) || $0.bool(forKey: DefaultsKeys.recognizeTextInPictures) } ?? true
    }
}
