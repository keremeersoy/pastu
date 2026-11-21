import AppKit

/// Resolves a bundle identifier to the app's display name and icon (cached; used by list rows and the preview).
@MainActor
enum AppLookup {
    private static var names: [String: String] = [:]
    private static var icons: [String: NSImage] = [:]

    static func name(for bundleIdentifier: String?) -> String? {
        guard let id = bundleIdentifier else { return nil }
        if let cached = names[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        names[id] = name
        return name
    }

    static func icon(for bundleIdentifier: String?) -> NSImage? {
        guard let id = bundleIdentifier else { return nil }
        if let cached = icons[id] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[id] = icon
        return icon
    }
}
