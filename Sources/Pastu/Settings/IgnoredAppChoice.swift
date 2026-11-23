import AppKit

/// Picking an app to ignore: the user chooses an app bundle, and its bundle identifier is what is stored.
@MainActor
enum IgnoredAppChoice {
    /// The identifier of the app bundle at `url`, or nil when it is not an app.
    static func bundleIdentifier(at url: URL) -> String? {
        guard url.pathExtension == "app", let id = Bundle(url: url)?.bundleIdentifier, !id.isEmpty else { return nil }
        return id
    }

    /// Shows the open panel on /Applications; nil when cancelled or the choice is not an app.
    static func chooseApp() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to ignore"
        panel.prompt = "Ignore"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return bundleIdentifier(at: url)
    }
}
