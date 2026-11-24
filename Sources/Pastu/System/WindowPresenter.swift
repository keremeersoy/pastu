import AppKit

/// Shows Pastu's own windows and alerts, and hands focus back afterwards.
///
/// Pastu is an accessory app: it is not frontmost, and its panel never activates it. A window or alert has to bring
/// Pastu forward to be usable, and when it closes Pastu must give the keyboard back to the app the user came from;
/// otherwise the next ⌘⇧V and Return would send ⌘V to Pastu itself and the paste would be lost.
@MainActor
final class WindowPresenter: NSObject {
    /// How focus is taken and given back; replaceable for tests.
    @MainActor
    struct Focus {
        var frontmostApp: @MainActor () -> NSRunningApplication? = { NSWorkspace.shared.frontmostApplication }
        var activatePastu: @MainActor () -> Void = { NSApp.activate() }
        var isPastuActive: @MainActor () -> Bool = { NSApp.isActive }
        var reactivate: @MainActor (NSRunningApplication) -> Void = { app in
            // Activation is cooperative since macOS 14: the active app has to yield to the one it hands over to.
            NSApp.yieldActivation(to: app)
            app.activate(from: .current, options: [])
        }
    }

    var focus = Focus()
    private var appBeforeWindow: NSRunningApplication?

    /// Brings Pastu forward, shows a window, and gives focus back to the previous app when that window closes.
    /// `show` returns the window it opened, or nil when it was open already; then the app to go back to, remembered
    /// the first time, is kept.
    func present(_ show: @MainActor () -> NSWindow?) {
        let previous = activatePastu()
        guard let window = show() else { return }
        appBeforeWindow = previous
        NotificationCenter.default.addObserver(
            self, selector: #selector(presentedWindowWillClose(_:)), name: NSWindow.willCloseNotification, object: window
        )
    }

    @objc private func presentedWindowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(
            self, name: NSWindow.willCloseNotification, object: notification.object
        )
        giveFocusBack(to: appBeforeWindow)
        appBeforeWindow = nil
    }

    /// Brings Pastu to the front and returns the app that was there, for `giveFocusBack`.
    func activatePastu() -> NSRunningApplication? {
        let previous = focus.frontmostApp()
        focus.activatePastu()
        return previous
    }

    /// Does nothing when the user already moved to another app.
    func giveFocusBack(to app: NSRunningApplication?) {
        guard let app, app != .current, focus.isPastuActive() else { return }
        focus.reactivate(app)
    }
}
