import AppKit
import PastuCore
import SwiftUI

/// Owns the Settings window: one at a time, built fresh each time it opens.
/// The window is as tall as its content, but never taller than the screen: the form scrolls instead.
@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private let glassAvailable: Bool
    private let setHotKeySuspended: (Bool) -> Void
    private let maxContentHeight: @MainActor () -> CGFloat
    private var window: NSWindow?

    /// "Show Welcome Guide…"; set by the app delegate once it exists.
    var showWelcome: () -> Void = {}
    /// "Find text in pictures" was switched on; set by the app delegate once the indexer exists.
    var onPictureTextEnabled: () -> Void = {}

    /// - Parameter setHotKeySuspended: lets the shortcut recorder silence the global shortcut while it listens.
    /// - Parameter maxContentHeight: the most height the content may take; replaceable for tests.
    init(
        settings: AppSettings, setHotKeySuspended: @escaping (Bool) -> Void = { _ in },
        glassAvailable: Bool = StatusMenuController.systemHasGlass,
        maxContentHeight: @escaping @MainActor () -> CGFloat = SettingsWindowController.heightThatFitsTheScreen
    ) {
        self.settings = settings
        self.setHotKeySuspended = setHotKeySuspended
        self.glassAvailable = glassAvailable
        self.maxContentHeight = maxContentHeight
    }

    /// Leaves room for the title bar, the menu bar and the Dock.
    static func heightThatFitsTheScreen() -> CGFloat {
        let screen = NSScreen.main?.visibleFrame.height ?? 800
        return max(screen - 140, 300)
    }

    /// Opens the window and returns it, or brings the open one forward and returns nil.
    func show() -> NSWindow? {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return nil
        }
        let content = SettingsView(
            settings: settings, recorder: ShortcutRecorder(hotKeys: settings.hotKeys, setSuspended: setHotKeySuspended),
            glassAvailable: glassAvailable,
            onPictureTextEnabled: { [weak self] in self?.onPictureTextEnabled() },
            showWelcome: { [weak self] in self?.showWelcome() }
        )
        let height = min(naturalHeight(of: content), maxContentHeight())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: SettingsView.width, height: height),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        // The controller keeps the window; a window that frees itself on close would leave a dangling reference.
        window.isReleasedWhenClosed = false
        window.title = "Settings"
        window.contentMinSize = NSSize(width: SettingsView.width, height: 240)
        window.contentMaxSize = NSSize(width: SettingsView.width, height: .greatestFiniteMagnitude)
        let hosting = NSHostingView(rootView: content)
        // The window keeps the size chosen above instead of following the form's ideal height.
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setContentSize(NSSize(width: SettingsView.width, height: height))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        return window
    }

    /// How tall the whole form wants to be, measured with a throwaway view.
    private func naturalHeight(of content: SettingsView) -> CGFloat {
        NSHostingView(rootView: content.fixedSize(horizontal: false, vertical: true)).fittingSize.height
    }
}
