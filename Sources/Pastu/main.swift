import AppKit
import Carbon.HIToolbox
import PastuCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var store: ClipStore?
    private var monitor: ClipboardMonitor?
    private var panelController: PanelController?
    private var hotKey: GlobalHotKey?
    private let systemPasteboard = SystemPasteboard()
    private var accessWarningItem: NSMenuItem?
    private var storageWarningItem: NSMenuItem?
    private var accessibilityWarningItem: NSMenuItem?
    /// Set when the history database could not be opened or written; shown in the menu.
    private var storageError: String?
    private let retention = RetentionPolicy()
    private let recording = RecordingState(defaults: .standard)
    private var model: ClipListModel?
    private let ignoredApps = IgnoredApps(defaults: .standard)
    private var ignoredMenuItem: NSMenuItem?
    private var pauseItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let store = try ClipStore(path: Self.databasePath())
            self.store = store
            try store.prune(retention)
            let model = ClipListModel(store: store)
            self.model = model
            let panelController = PanelController(
                model: model,
                canAutoPaste: { PasteSender.isTrusted },
                ignoredApps: ignoredApps,
                imageData: { id in (try? store.imageData(id: id)) ?? nil }
            ) { [weak self] clip in
                self?.paste(clip)
            }
            self.panelController = panelController

            let monitor = ClipboardMonitor(
                source: systemPasteboard,
                filter: PrivacyFilter(ignoredBundleIdentifiers: ignoredApps.bundleIdentifiers),
                recording: recording
            ) { [weak self] clip in
                guard let self else { return }
                do {
                    try store.insert(clip)
                    try store.prune(self.retention)
                    self.storageError = nil
                } catch {
                    NSLog("Pastu could not save a clip: \(error)")
                    self.storageError = "could not save: \(error)"
                }
                if self.panelController?.isVisible == true { model.refresh() }
            }
            // Adding or removing an ignored app takes effect for the very next copy.
            ignoredApps.onChange = { [weak monitor] ids in monitor?.filter.ignoredBundleIdentifiers = ids }
            monitor.start()
            self.monitor = monitor
        } catch {
            NSLog("Pastu could not open its database: \(error)")
            storageError = "could not open history: \(error)"
        }

        // ⌘⇧V
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.panelController?.toggle()
        }
        if hotKey == nil { NSLog("Pastu could not register its global hotkey") }

        setUpStatusItem()

        // Ask for the Accessibility permission right away (once per launch) instead of failing silently
        // at the first paste. The system dialog has a button that opens the right Settings pane.
        if !PasteSender.isTrusted {
            didPromptForAccessibility = true
            PasteSender.requestTrust()
        }
    }

    private var didPromptForAccessibility = false

    /// Puts the clip on the pasteboard and sends ⌘V to the app the user came from.
    private func paste(_ clip: StoredClip) {
        // Text or picture, written without Pastu recapturing its own write. Nothing to paste if the picture is gone.
        guard let store, let monitor, ClipPasteboardWriter.copy(clip, from: store, using: monitor) else { return }
        try? store.markUsed(id: clip.id)

        guard PasteSender.isTrusted else {
            // The clip is already on the clipboard, so a manual ⌘V still works.
            if !didPromptForAccessibility {
                didPromptForAccessibility = true
                PasteSender.requestTrust()
            }
            return
        }
        Task { @MainActor in
            // Give the panel a moment to disappear so the key event reaches the previous app.
            try? await Task.sleep(for: .milliseconds(80))
            PasteSender.sendCommandV()
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleRecording() {
        recording.toggle()
        updatePauseUI()
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
        } catch {
            NSLog("Pastu could not clear the history: \(error)")
            storageError = "could not clear: \(error)"
        }
        model?.refresh()
    }

    @objc private func togglePanel() {
        panelController?.toggle()
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

    private func setUpStatusItem() {
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

    /// ~/Library/Application Support/Pastu/history.sqlite (created on first launch).
    private static func databasePath() throws -> String {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent(PastuInfo.name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        // createDirectory leaves an existing folder untouched, so tighten it explicitly.
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        return dir.appendingPathComponent("history.sqlite").path
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
// Menu bar only: no Dock icon.
app.setActivationPolicy(.accessory)
app.run()
