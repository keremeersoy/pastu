import PastuCore
import SwiftUI

/// The Settings window's content: one section after another, in a form that scrolls when the screen is short.
struct SettingsView: View {
    static let width: CGFloat = 420

    let settings: AppSettings
    let recorder: ShortcutRecorder
    let glassAvailable: Bool
    var onPictureTextEnabled: () -> Void = {}
    var showWelcome: () -> Void = {}

    var body: some View {
        Form {
            GeneralSection(launchAtLogin: settings.launchAtLogin, showWelcome: showWelcome)
            ShortcutSection(hotKeys: settings.hotKeys, recorder: recorder)
            HistorySection(retention: settings.retention)
            SearchSection(pictureText: settings.pictureText, onEnabled: onPictureTextEnabled)
            PasteQueueSection(queue: settings.queue)
            IgnoredAppsSection(ignoredApps: settings.ignoredApps)
            AppearanceSection(theme: settings.theme, glassAvailable: glassAvailable)
        }
        .formStyle(.grouped)
        // Recording ends with the window: a shortcut left suspended would stop working.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in recorder.stop() }
        .onDisappear { recorder.stop() }
        .frame(width: Self.width)
    }
}
