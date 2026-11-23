import AppKit
import PastuCore
import SwiftUI

/// Owns the Settings window: one at a time, built fresh each time it opens.
@MainActor
final class SettingsWindowController {
    private let theme: ThemeSettings
    private let launchAtLogin: LaunchAtLogin
    private let hotKeys: HotKeySettings
    private let retention: RetentionSettings
    private let ignoredApps: IgnoredApps
    private let queueSettings: QueueSettings
    /// "Show Welcome Guide…"; set by the app delegate once it exists.
    var showWelcome: () -> Void = {}
    private let setHotKeySuspended: (Bool) -> Void
    private let glassAvailable: Bool
    private var window: NSWindow?

    init(theme: ThemeSettings, launchAtLogin: LaunchAtLogin, hotKeys: HotKeySettings, retention: RetentionSettings, ignoredApps: IgnoredApps,
         queueSettings: QueueSettings, setHotKeySuspended: @escaping (Bool) -> Void = { _ in },
         glassAvailable: Bool = StatusMenuController.systemHasGlass) {
        self.theme = theme
        self.launchAtLogin = launchAtLogin
        self.hotKeys = hotKeys
        self.retention = retention
        self.ignoredApps = ignoredApps
        self.queueSettings = queueSettings
        self.setHotKeySuspended = setHotKeySuspended
        self.glassAvailable = glassAvailable
    }

    /// Opens the window and returns it, or brings the open one forward and returns nil.
    func show() -> NSWindow? {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return nil
        }
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        // The controller keeps the window; a window that frees itself on close would leave a dangling reference.
        window.isReleasedWhenClosed = false
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: SettingsView(
            theme: theme, launchAtLogin: launchAtLogin, hotKeys: hotKeys, retention: retention, ignoredApps: ignoredApps, queueSettings: queueSettings, showWelcome: { [weak self] in self?.showWelcome() },
            recorder: ShortcutRecorder(hotKeys: hotKeys, setSuspended: setHotKeySuspended),
            glassAvailable: glassAvailable
        ))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        return window
    }
}
