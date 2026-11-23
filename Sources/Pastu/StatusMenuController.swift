import AppKit
import PastuCore

/// The menu bar item and its menu: show the panel, pause, clear history, ignored apps, warnings, quit.
/// Warnings and the ignored-apps submenu are refreshed every time the menu opens.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    /// Set once the database is open; "Clear History…" does nothing without it.
    var store: ClipStore?
    var model: ClipListModel?
    /// What went wrong with the history database, if anything. The raw error goes to `NSLog` where it happens;
    /// the menu only shows a short, human sentence.
    enum StorageProblem {
        case open, save, clear

        var message: String {
            switch self {
            case .open: "Pastu can't open its history"
            case .save: "Pastu can't save new clips right now"
            case .clear: "Pastu couldn't clear the history"
            }
        }
    }

    var storageError: StorageProblem?
    var onShowPanel: () -> Void = {}

    /// How the alert and the About window take focus and give it back; replaceable for tests.
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
    /// Runs the Clear History alert; replaceable so tests can answer it.
    var runAlert: (NSAlert) -> NSApplication.ModalResponse = { $0.runModal() }
    /// Shows the About window and returns it, or nil when it was open already; replaceable for tests.
    var showAboutPanel: @MainActor () -> NSWindow? = StatusMenuController.orderFrontAboutPanel
    /// Shows the Settings window and returns it, or nil when it was open already; set by the app delegate.
    var showSettingsWindow: @MainActor () -> NSWindow? = { nil }

    private let recording: RecordingState
    private let ignoredApps: IgnoredApps
    private let systemPasteboard: SystemPasteboard
    private let theme: ThemeSettings
    private let glassAvailable: Bool

    private var appBeforeWindow: NSRunningApplication?
    private var statusItem: NSStatusItem?
    private var accessWarningItem: NSMenuItem?
    private var storageWarningItem: NSMenuItem?
    private var accessibilityWarningItem: NSMenuItem?
    private var ignoredMenuItem: NSMenuItem?
    private var themeMenuItem: NSMenuItem?
    private var pauseItem: NSMenuItem?

    /// - Parameter glassAvailable: whether Liquid Glass can be drawn (macOS 26+); replaceable for tests.
    init(
        recording: RecordingState, ignoredApps: IgnoredApps, systemPasteboard: SystemPasteboard,
        theme: ThemeSettings = ThemeSettings(), glassAvailable: Bool = StatusMenuController.systemHasGlass
    ) {
        self.recording = recording
        self.ignoredApps = ignoredApps
        self.systemPasteboard = systemPasteboard
        self.theme = theme
        self.glassAvailable = glassAvailable
        super.init()
    }

    static var systemHasGlass: Bool {
        if #available(macOS 26, *) { true } else { false }
    }

    /// The menu, for tests.
    var menuForTesting: NSMenu { menu }
    private var menu = NSMenu()

    /// What VoiceOver says for the menu bar icon.
    static func accessibilityDescription(isPaused: Bool) -> String {
        isPaused ? "\(PastuInfo.name) (paused)" : PastuInfo.name
    }

    /// Builds the menu and, unless `inStatusBar` is false (tests), adds the item to the menu bar. Call once, after launch.
    func install(inStatusBar: Bool = true) {
        let menu = NSMenu()
        self.menu = menu
        let warning = NSMenuItem(
            title: "Pastu can't read the clipboard — open Privacy settings…",
            action: #selector(openPrivacySettings), keyEquivalent: ""
        )
        warning.target = self
        warning.isHidden = true
        menu.addItem(warning)
        warning.image = Self.warningImage
        accessWarningItem = warning
        menu.delegate = self

        let accessibilityWarning = NSMenuItem(
            title: "Pastu needs Accessibility permission to paste — open Settings…",
            action: #selector(openAccessibilitySettings), keyEquivalent: ""
        )
        accessibilityWarning.target = self
        accessibilityWarning.image = Self.warningImage
        accessibilityWarning.isHidden = true
        menu.addItem(accessibilityWarning)
        accessibilityWarningItem = accessibilityWarning

        let storageWarning = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        storageWarning.image = Self.warningImage
        storageWarning.isHidden = true
        menu.addItem(storageWarning)
        storageWarningItem = storageWarning

        // Display only: the Carbon hotkey is the real trigger. Showing it teaches the shortcut.
        let show = menu.addItem(withTitle: "Show \(PastuInfo.name)", action: #selector(togglePanel), keyEquivalent: "v")
        show.keyEquivalentModifierMask = [.command, .shift]
        show.target = self
        let pause = menu.addItem(withTitle: "Pause Recording", action: #selector(toggleRecording), keyEquivalent: "")
        pause.target = self
        pauseItem = pause
        menu.addItem(withTitle: "Clear History…", action: #selector(clearHistory), keyEquivalent: "")
            .target = self
        let ignored = NSMenuItem(title: "Ignored Apps", action: nil, keyEquivalent: "")
        ignored.submenu = NSMenu()
        menu.addItem(ignored)
        ignoredMenuItem = ignored
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = NSMenu()
        menu.addItem(themeItem)
        themeMenuItem = themeItem
        rebuildThemeMenu()
        menu.addItem(.separator())
        menu.addItem(withTitle: "About \(PastuInfo.name)", action: #selector(showAbout), keyEquivalent: "")
            .target = self
        // Display only, like ⌘⇧V above: the menu is the only place it is shown.
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(
            withTitle: "Quit \(PastuInfo.name)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        if inStatusBar {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.menu = menu
            statusItem = item
        }
        updatePauseUI()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildIgnoredAppsMenu()
        rebuildThemeMenu()
        accessWarningItem?.isHidden = !systemPasteboard.isAccessDenied
        accessibilityWarningItem?.isHidden = PasteSender.isTrusted
        if let storageError {
            storageWarningItem?.title = storageError.message
            storageWarningItem?.isHidden = false
        } else {
            storageWarningItem?.isHidden = true
        }
    }

    // MARK: Actions

    @objc private func openAccessibilitySettings() {
        SystemSettings.openAccessibility()
    }

    @objc private func openPrivacySettings() {
        SystemSettings.openPrivacy()
    }

    @objc func toggleRecording() {
        recording.toggle()
        updatePauseUI()
    }

    /// The panel's "Resume" button: same as the menu item, so the menu bar icon updates too.
    func resumeRecording() {
        guard recording.isPaused else { return }
        toggleRecording()
    }

    private func updatePauseUI() {
        // A checkmark, not a renamed item: the menu keeps one stable label per action.
        pauseItem?.state = recording.isPaused ? .on : .off
        let symbol = recording.isPaused ? "pause.circle" : "doc.on.clipboard"
        statusItem?.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: Self.accessibilityDescription(isPaused: recording.isPaused)
        )
        statusItem?.button?.appearsDisabled = recording.isPaused
    }

    @objc func clearHistory() {
        guard let store else { return }
        // An accessory app is not frontmost; without this the alert can open behind other windows.
        let previous = activatePastu()
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All clips except pinned ones will be deleted. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        let answer = runAlert(alert)
        giveFocusBack(to: previous)
        guard answer == .alertFirstButtonReturn else { return }
        do {
            try store.clear(keepPinned: true)
            storageError = nil
            PanelCaches.purgeAll(model: model)
        } catch {
            NSLog("Pastu could not clear the history: \(error)")
            storageError = .clear
        }
        model?.refresh()
    }

    @objc func showAbout() {
        present(showAboutPanel)
    }

    @objc func showSettings() {
        present(showSettingsWindow)
    }

    /// Brings Pastu forward, shows a window, and gives focus back to the previous app when that window closes.
    private func present(_ show: @MainActor () -> NSWindow?) {
        let previous = activatePastu()
        // Nil when it is open already: the app to go back to was remembered the first time.
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
    private func activatePastu() -> NSRunningApplication? {
        let previous = focus.frontmostApp()
        focus.activatePastu()
        return previous
    }

    /// An accessory app stays frontmost after its alert or window closes, and the panel does not activate anything:
    /// without this, the next ⌘⇧V and Return would send ⌘V to Pastu itself and the paste would be lost. Does nothing
    /// when the user already moved to another app.
    private func giveFocusBack(to app: NSRunningApplication?) {
        guard let app, app != .current, focus.isPastuActive() else { return }
        focus.reactivate(app)
    }

    /// The standard panel's window has no public accessor: it is the one that became visible.
    private static func orderFrontAboutPanel() -> NSWindow? {
        let open = NSApp.windows.filter(\.isVisible)
        NSApp.orderFrontStandardAboutPanel(nil)
        return NSApp.windows.first { $0.isVisible && !open.contains($0) }
    }

    private static var warningImage: NSImage? {
        NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Warning")
    }

    @objc private func togglePanel() {
        onShowPanel()
    }

    /// Rebuilt every time the menu opens: one "Stop ignoring …" entry per ignored app.
    private func rebuildIgnoredAppsMenu() {
        guard let submenu = ignoredMenuItem?.submenu else { return }
        submenu.removeAllItems()
        let ids = ignoredApps.sortedIdentifiers
        if ids.isEmpty {
            let none = NSMenuItem(title: "None (press ⌘I on a clip in the panel)", action: nil, keyEquivalent: "")
            none.isEnabled = false
            submenu.addItem(none)
            return
        }
        for id in ids {
            let name = AppLookup.name(for: id) ?? id
            let item = NSMenuItem(title: "Stop ignoring \(name)", action: #selector(stopIgnoring(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            submenu.addItem(item)
        }
    }

    /// Appearance and material choices with a checkmark on the current ones. Rebuilt on every change and every open.
    /// A stored Liquid Glass choice is checked as Frosted where glass does not exist, matching what is drawn.
    private func rebuildThemeMenu() {
        guard let submenu = themeMenuItem?.submenu else { return }
        submenu.removeAllItems()
        submenu.addItem(.sectionHeader(title: "Appearance"))
        for appearance in PanelAppearance.allCases {
            let item = NSMenuItem(title: appearance.title, action: #selector(chooseAppearance(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = appearance.rawValue
            item.state = theme.appearance == appearance ? .on : .off
            submenu.addItem(item)
        }
        submenu.addItem(.separator())
        submenu.addItem(.sectionHeader(title: "Material"))
        let current = theme.material.resolved(glassAvailable: glassAvailable)
        for material in PanelMaterial.choices(glassAvailable: glassAvailable) {
            let item = NSMenuItem(title: material.title, action: #selector(chooseMaterial(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = material.rawValue
            item.state = current == material ? .on : .off
            submenu.addItem(item)
        }
    }

    @objc private func chooseAppearance(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let appearance = PanelAppearance(rawValue: raw) else { return }
        theme.appearance = appearance
        rebuildThemeMenu()
    }

    @objc private func chooseMaterial(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let material = PanelMaterial(rawValue: raw) else { return }
        theme.material = material
        rebuildThemeMenu()
    }

    @objc private func stopIgnoring(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { ignoredApps.remove(id) }
    }
}
