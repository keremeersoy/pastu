import AppKit

/// Resolves a bundle identifier to the app's display name and icon (cached; used by list rows and the preview).
/// "Not found" is cached too: rows ask again on every rebuild, and an uninstalled app would otherwise cost a
/// LaunchServices query each time. An app installed later shows up after Pastu restarts.
@MainActor
enum AppLookup {
    private static var names: [String: String?] = [:]
    private static var icons: [String: NSImage?] = [:]
    /// Asks LaunchServices; replaceable so tests can count the calls.
    static var findApp: (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }

    static func name(for bundleIdentifier: String?) -> String? {
        guard let id = bundleIdentifier else { return nil }
        if let cached = names[id] { return cached }
        let name = findApp(id).map {
            FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "")
        }
        // `updateValue`, because assigning nil through the subscript would remove the entry instead of storing it.
        names.updateValue(name, forKey: id)
        return name
    }

    static func icon(for bundleIdentifier: String?) -> NSImage? {
        guard let id = bundleIdentifier else { return nil }
        if let cached = icons[id] { return cached }
        let icon = findApp(id).map { NSWorkspace.shared.icon(forFile: $0.path) }
        icons.updateValue(icon, forKey: id)
        return icon
    }
}
