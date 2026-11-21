import AppKit
import Carbon.HIToolbox
import PastuCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var store: ClipStore?
    private var monitor: ClipboardMonitor?
    private var panelController: PanelController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let store = try ClipStore(path: Self.databasePath())
            self.store = store
            let model = ClipListModel(store: store)
            let panelController = PanelController(model: model)
            self.panelController = panelController

            let monitor = ClipboardMonitor(source: SystemPasteboard(), filter: PrivacyFilter()) { [weak self] clip in
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

    @objc private func togglePanel() {
        panelController?.toggle()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: PastuInfo.name
        )

        let menu = NSMenu()
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
