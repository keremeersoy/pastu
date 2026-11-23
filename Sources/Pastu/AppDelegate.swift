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
    private let retention: RetentionSettings
    private let recording: RecordingState
    private let ignoredApps: IgnoredApps
    private let theme: ThemeSettings
    private let statusMenu: StatusMenuController
    private let settingsWindow: SettingsWindowController
    private let onboarding: Onboarding
    private let queueSettings: QueueSettings
    private let pictureText: PictureTextSettings
    private var indexer: PictureIndexer?
    private let launchAtLogin = LaunchAtLogin(service: SystemLoginItem())
    private var onboardingWindow: OnboardingWindowController?
    private let pasteCoordinator = PasteCoordinator()

    override init() {
        let systemPasteboard = SystemPasteboard()
        let recording = RecordingState(store: UserDefaults.standard)
        let ignoredApps = IgnoredApps(store: UserDefaults.standard)
        let theme = ThemeSettings(store: UserDefaults.standard)
        self.theme = theme
        let queueSettings = QueueSettings(store: UserDefaults.standard)
        self.queueSettings = queueSettings
        let pictureText = PictureTextSettings(store: UserDefaults.standard)
        self.pictureText = pictureText
        let onboarding = Onboarding(store: UserDefaults.standard)
        self.onboarding = onboarding
        let retention = RetentionSettings(store: UserDefaults.standard)
        self.retention = retention
        let registrar = hotKeyRegistrar
        let hotKeys = HotKeySettings(store: UserDefaults.standard) { registrar.register($0) }
        self.hotKeys = hotKeys
        self.systemPasteboard = systemPasteboard
        self.recording = recording
        self.ignoredApps = ignoredApps
        statusMenu = StatusMenuController(recording: recording, ignoredApps: ignoredApps, systemPasteboard: systemPasteboard, theme: theme, hotKeys: hotKeys)
        settingsWindow = SettingsWindowController(
            theme: theme, launchAtLogin: launchAtLogin, hotKeys: hotKeys, retention: retention, ignoredApps: ignoredApps,
            queueSettings: queueSettings, pictureText: pictureText,
            setHotKeySuspended: { registrar.isSuspended = $0 }
        )
        super.init()
        statusMenu.showSettingsWindow = { [settingsWindow] in settingsWindow.show() }
        settingsWindow.showWelcome = { [weak self] in self?.showWelcome() }
        settingsWindow.onPictureTextEnabled = { [weak self] in self?.indexer?.catchUp() }
        statusMenu.onShowPanel = { [weak self] in self?.panelController?.toggle() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PreviewOpener.shared.cleanUp()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Leftovers of "Open in Preview" from a run that did not quit cleanly.
        PreviewOpener.shared.cleanUp()
        do {
            let store = try ClipStore(path: AppPaths.databasePath())
            self.store = store
            try store.prune(retention.policy)
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
                theme: theme,
                queueSettings: queueSettings,
                onPasteQueue: { [weak self] steps in
                    Task { @MainActor in await self?.pasteCoordinator.pasteQueue(steps) }
                }
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
                    let id = try store.insert(clip)
                    if clip.imagePNG != nil { self.indexer?.enqueue(id) }
                    try store.prune(self.retention.policy)
                    self.statusMenu.storageError = nil
                } catch {
                    NSLog("Pastu could not save a clip: \(error)")
                    self.statusMenu.storageError = .save
                }
                if self.panelController?.isVisible == true { model.refresh() }
            }
            // Adding or removing an ignored app takes effect for the very next copy.
            ignoredApps.onChange = { [weak monitor] ids in monitor?.filter.ignoredBundleIdentifiers = ids }
            // Reads the words in pictures in the background so screenshots can be searched; pictures from before this
            // existed are caught up a few seconds after launch, so starting Pastu stays quick.
            let indexer = PictureIndexer(
                store: store, recognizer: VisionTextRecognizer(),
                isEnabled: { [pictureText] in pictureText.isEnabled },
                onIndexed: { [weak self] in if self?.panelController?.isVisible == true { model.refresh() } }
            )
            self.indexer = indexer
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                indexer.catchUp()
            }
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
        // A new install gets the welcome guide, whose second step asks for the permission with an explanation.
        if onboarding.isNeeded {
            showWelcome()
        } else {
            pasteCoordinator.requestAccessibilityIfNeeded()
        }
    }

    /// Opens the welcome guide from its first step (first launch, or "Show Welcome Guide…" in Settings).
    private func showWelcome() {
        onboarding.restart()
        let controller = onboardingWindow ?? OnboardingWindowController(
            onboarding: onboarding, hotKeys: hotKeys, launchAtLogin: launchAtLogin,
            isTrusted: { PasteSender.isTrusted },
            requestAccessibility: { [weak self] in self?.pasteCoordinator.requestAccessibilityIfNeeded() },
            openAccessibilitySettings: SystemSettings.openAccessibility
        )
        onboardingWindow = controller
        NSApp.activate()
        _ = controller.show()
    }
}
