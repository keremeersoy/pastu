import AppKit
import PastuCore
import SwiftUI

/// Owns the Settings window: one at a time, built fresh each time it opens.
@MainActor
final class SettingsWindowController {
    private let theme: ThemeSettings
    private let glassAvailable: Bool
    private var window: NSWindow?

    init(theme: ThemeSettings, glassAvailable: Bool = StatusMenuController.systemHasGlass) {
        self.theme = theme
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
        window.contentView = NSHostingView(rootView: SettingsView(theme: theme, glassAvailable: glassAvailable))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        return window
    }
}
