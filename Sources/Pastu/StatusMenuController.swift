import AppKit
import PastuCore

/// The menu bar item and its menu: show the panel, pause, clear history, ignored apps, warnings, quit.
/// Warnings and the ignored-apps submenu are refreshed every time the menu opens.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    /// Set once the database is open; "Clear history…" does nothing without it.
    var store: ClipStore?
    var model: ClipListModel?
    /// Set when the history database could not be opened or written; shown in the menu.
    var storageError: String?
    var onShowPanel: () -> Void = {}

    private let recording: RecordingState
    private let ignoredApps: IgnoredApps
    private let systemPasteboard: SystemPasteboard

    private var statusItem: NSStatusItem?
    private var accessWarningItem: NSMenuItem?
    private var storageWarningItem: NSMenuItem?
    private var accessibilityWarningItem: NSMenuItem?
    private var ignoredMenuItem: NSMenuItem?
    private var pauseItem: NSMenuItem?

    init(recording: RecordingState, ignoredApps: IgnoredApps, systemPasteboard: SystemPasteboard) {
        self.recording = recording
        self.ignoredApps = ignoredApps
        self.systemPasteboard = systemPasteboard
        super.init()
    }

    /// Adds the item to the menu bar. Call once, after launch.
    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: PastuInfo.name
        )

        let menu = NSMenu()
        let warning = NSMenuItem(
            title: "Clipboard access is denied — open Privacy settings…",
            action: #selector(openPrivacySettings), keyEquivalent: ""
        )
        warning.target = self
        warning.isHidden = true
        menu.addItem(warning)
        accessWarningItem = warning
        menu.delegate = self

        let accessibilityWarning = NSMenuItem(
            title: "Pastu needs Accessibility permission to paste — open settings…",
            action: #selector(openAccessibilitySettings), keyEquivalent: ""
        )
        accessibilityWarning.target = self
        accessibilityWarning.isHidden = true
        menu.addItem(accessibilityWarning)
        accessibilityWarningItem = accessibilityWarning

        let storageWarning = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        storageWarning.isHidden = true
        menu.addItem(storageWarning)
        storageWarningItem = storageWarning

        menu.addItem(withTitle: "Show \(PastuInfo.name)", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        let pause = menu.addItem(withTitle: "Pause recording", action: #selector(toggleRecording), keyEquivalent: "")
        pause.target = self
        pauseItem = pause
        menu.addItem(withTitle: "Clear history…", action: #selector(clearHistory), keyEquivalent: "")
            .target = self
        let ignored = NSMenuItem(title: "Ignored apps", action: nil, keyEquivalent: "")
        ignored.submenu = NSMenu()
        menu.addItem(ignored)
        ignoredMenuItem = ignored
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit \(PastuInfo.name)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item
        updatePauseUI()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildIgnoredAppsMenu()
        accessWarningItem?.isHidden = !systemPasteboard.isAccessDenied
        accessibilityWarningItem?.isHidden = PasteSender.isTrusted
        if let storageError {
            storageWarningItem?.title = "⚠︎ History problem: \(storageError)"
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

    @objc private func toggleRecording() {
        recording.toggle()
        updatePauseUI()
    }

    /// The panel's "Resume" button: same as the menu item, so the menu bar icon updates too.
    func resumeRecording() {
        guard recording.isPaused else { return }
        toggleRecording()
    }

    private func updatePauseUI() {
        pauseItem?.title = recording.isPaused ? "Resume recording" : "Pause recording"
        let symbol = recording.isPaused ? "pause.circle" : "doc.on.clipboard"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: PastuInfo.name)
        statusItem?.button?.appearsDisabled = recording.isPaused
    }

    @objc private func clearHistory() {
        guard let store else { return }
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All clips except pinned ones will be deleted. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try store.clear(keepPinned: true)
            storageError = nil
            PanelCaches.purge()
        } catch {
            NSLog("Pastu could not clear the history: \(error)")
            storageError = "could not clear: \(error)"
        }
        model?.refresh()
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

    @objc private func stopIgnoring(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { ignoredApps.remove(id) }
    }
}
