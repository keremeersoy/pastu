import AppKit

/// Deep links into System Settings, shared by the menu bar menu and the panel.
enum SystemSettings {
    /// Privacy & Security › Accessibility, where the user lets Pastu send ⌘V.
    static func openAccessibility() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    /// Privacy & Security, for clipboard (pasteboard) access.
    static func openPrivacy() {
        open("x-apple.systempreferences:com.apple.preference.security")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
