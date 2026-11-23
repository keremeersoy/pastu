import AppKit
import PastuCore
import SwiftUI

/// Owns the welcome guide window: one at a time. Closing it, by Done or the red button, finishes the guide.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let onboarding: Onboarding
    private let hotKeys: HotKeySettings
    private let launchAtLogin: LaunchAtLogin
    private let isTrusted: () -> Bool
    private let requestAccessibility: () -> Void
    private let openAccessibilitySettings: () -> Void
    private var window: NSWindow?

    init(
        onboarding: Onboarding, hotKeys: HotKeySettings, launchAtLogin: LaunchAtLogin,
        isTrusted: @escaping () -> Bool, requestAccessibility: @escaping () -> Void,
        openAccessibilitySettings: @escaping () -> Void
    ) {
        self.onboarding = onboarding
        self.hotKeys = hotKeys
        self.launchAtLogin = launchAtLogin
        self.isTrusted = isTrusted
        self.requestAccessibility = requestAccessibility
        self.openAccessibilitySettings = openAccessibilitySettings
        super.init()
    }

    /// Opens the window at the current step and returns it, or brings the open one forward and returns nil.
    func show() -> NSWindow? {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return nil
        }
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.title = PastuInfo.name
        window.delegate = self
        window.contentView = NSHostingView(rootView: OnboardingView(
            onboarding: onboarding, hotKeys: hotKeys, launchAtLogin: launchAtLogin,
            isTrusted: isTrusted, requestAccessibility: requestAccessibility,
            openAccessibilitySettings: openAccessibilitySettings,
            finish: { [weak self] in self?.window?.close() }
        ))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        onboarding.finish()
    }
}
