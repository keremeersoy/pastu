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

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let store = try ClipStore(path: Self.databasePath())
            self.store = store
            let model = ClipListModel(store: store)
            let panelController = PanelController(model: model) { [weak self] clip in
                self?.paste(clip)
            }
            self.panelController = panelController

            let monitor = ClipboardMonitor(source: systemPasteboard, filter: PrivacyFilter()) { [weak self] clip in
                _ = try? store.insert(clip)
                if self?.panelController?.isVisible == true { model.refresh() }
            }
            monitor.start()
            self.monitor = monitor
        } catch {
            NSLog("Pastu could not open its database: \(error)")
        }

        // ⌘⇧V
        hotKey = GlobalHotKey(keyCode: kVK_ANSI_V, modifiers: cmdKey | shiftKey) { [weak self] in
            self?.panelController?.toggle()
        }
        if hotKey == nil { NSLog("Pastu could not register its global hotkey") }

        setUpStatusItem()
    }

    private var didPromptForAccessibility = false

    /// Puts the clip on the pasteboard and sends ⌘V to the app the user came from.
    private func paste(_ clip: StoredClip) {
        monitor?.copyToPasteboard(clip.text)
        try? store?.markUsed(id: clip.id)

        guard PasteSender.isTrusted else {
            // The text is already on the clipboard, so a manual ⌘V still works.
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

    @objc private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func togglePanel() {
        panelController?.toggle()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        accessWarningItem?.isHidden = !systemPasteboard.isAccessDenied
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

        menu.addItem(withTitle: "Show \(PastuInfo.name)", action: #selector(togglePanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit \(PastuInfo.name)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item
    }

    /// ~/Library/Application Support/Pastu/history.sqlite (created on first launch).
    private static func databasePath() throws -> String {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent(PastuInfo.name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.sqlite").path
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
// Menu bar only: no Dock icon.
app.setActivationPolicy(.accessory)
app.run()
