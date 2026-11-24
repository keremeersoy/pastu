import PastuCore

/// Every setting Pastu keeps, built once at launch and handed to whoever needs it (menu, panel, windows).
/// What gets remembered, and where, is decided here: the app passes `UserDefaults`, tests pass memory.
@MainActor
final class AppSettings {
    let recording: RecordingState
    let ignoredApps: IgnoredApps
    let theme: ThemeSettings
    let retention: RetentionSettings
    let queue: QueueSettings
    let pictureText: PictureTextSettings
    let onboarding: Onboarding
    let hotKeys: HotKeySettings
    let launchAtLogin: LaunchAtLogin

    /// - Parameter loginItem: the system's login-item service (a fake in tests).
    /// - Parameter registerHotKey: registers the global shortcut; false when the combination is taken.
    init(
        store: SettingsStore, loginItem: LoginItemService,
        registerHotKey: @escaping @MainActor (HotKeyCombo) -> Bool
    ) {
        recording = RecordingState(store: store)
        ignoredApps = IgnoredApps(store: store)
        theme = ThemeSettings(store: store)
        retention = RetentionSettings(store: store)
        queue = QueueSettings(store: store)
        pictureText = PictureTextSettings(store: store)
        onboarding = Onboarding(store: store)
        hotKeys = HotKeySettings(store: store, register: registerHotKey)
        launchAtLogin = LaunchAtLogin(service: loginItem)
    }
}
