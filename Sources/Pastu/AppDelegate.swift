import AppKit
import Carbon.HIToolbox
import PastuCore

/// Wires the pieces together at launch: storage, clipboard monitor, panel, hotkey and menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ClipStore?
    private var monitor: ClipboardMonitor?
    private var panelController: PanelController?
    private let hotKeyRegistrar = HotKeyRegistrar()
    private let hotKeys: HotKeySettings
    private let systemPasteboard: SystemPasteboard
    private let retention = RetentionPolicy()
    private let recording: RecordingState
    private let ignoredApps: IgnoredApps
    private let theme: ThemeSettings
    private let statusMenu: StatusMenuController
    private let settingsWindow: SettingsWindowController
    private let pasteCoordinator = PasteCoordinator()

    override init() {
        let systemPasteboard = SystemPasteboard()
        let recording = RecordingState(store: UserDefaults.standard)
        let ignoredApps = IgnoredApps(store: UserDefaults.standard)
        let theme = ThemeSettings(store: UserDefaults.standard)
        self.theme = theme
        let registrar = hotKeyRegistrar
        let hotKeys = HotKeySettings(store: UserDefaults.standard) { registrar.register($0) }
        self.hotKeys = hotKeys
        self.systemPasteboard = systemPasteboard
        self.recording = recording
        self.ignoredApps = ignoredApps
        statusMenu = StatusMenuController(recording: recording, ignoredApps: ignoredApps, systemPasteboard: systemPasteboard, theme: theme, hotKeys: hotKeys)
        settingsWindow = SettingsWindowController(
            theme: theme, launchAtLogin: LaunchAtLogin(service: SystemLoginItem()), hotKeys: hotKeys,
            setHotKeySuspended: { registrar.isSuspended = $0 }
        )
        super.init()
        statusMenu.showSettingsWindow = { [settingsWindow] in settingsWindow.show() }
        statusMenu.onShowPanel = { [weak self] in self?.panelController?.toggle() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let store = try ClipStore(path: AppPaths.databasePath())
            self.store = store
            try store.prune(retention)
            let model = ClipListModel(store: store)
            statusMenu.store = store
            statusMenu.model = model
            pasteCoordinator.store = store
            let panelController = PanelController(
                model: model,
                canAutoPaste: { PasteSender.isTrusted },
                ignoredApps: ignoredApps,
                imageData: { id in (try? store.imageData(id: id)) ?? nil },
                isPaused: { [recording] in recording.isPaused },
                onResume: { [weak self] in self?.statusMenu.resumeRecording() },
                onCopy: { [weak self] clip in self?.pasteCoordinator.copy(clip) },
                theme: theme
            ) { [weak self] clip in
                self?.pasteCoordinator.paste(clip)
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
                    self.statusMenu.storageError = nil
                } catch {
                    NSLog("Pastu could not save a clip: \(error)")
                    self.statusMenu.storageError = .save
                }
                if self.panelController?.isVisible == true { model.refresh() }
            }
            // Adding or removing an ignored app takes effect for the very next copy.
            ignoredApps.onChange = { [weak monitor] ids in monitor?.filter.ignoredBundleIdentifiers = ids }
            monitor.start()
            self.monitor = monitor
            pasteCoordinator.monitor = monitor
        } catch {
            NSLog("Pastu could not open its database: \(error)")
            statusMenu.storageError = .open
        }

        // The user's shortcut (⇧⌘V by default).
        hotKeyRegistrar.action = { [weak self] in self?.panelController?.toggle() }
        hotKeys.apply()
        if hotKeys.errorMessage != nil { NSLog("Pastu could not register its global hotkey") }

        statusMenu.install()

        // Ask for the Accessibility permission right away (once per launch) instead of failing silently
        // at the first paste.
        pasteCoordinator.requestAccessibilityIfNeeded()
    }
}
