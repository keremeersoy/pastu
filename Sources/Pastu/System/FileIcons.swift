import AppKit

/// Finder's icon for a path, remembered: rows redraw on every hover and key press, and asking the system each time
/// would add up. Bounded, like the picture thumbnails.
@MainActor
enum FileIcons {
    private static var icons: [String: NSImage] = [:]
    static let maxEntries = 300

    static func icon(forPath path: String) -> NSImage {
        if let cached = icons[path] { return cached }
        if icons.count >= maxEntries { icons.removeAll(keepingCapacity: true) }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }

    static func purge() { icons.removeAll() }
}
