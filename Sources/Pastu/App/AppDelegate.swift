import AppKit
import PastuCore

/// Wires the pieces together at launch: storage, clipboard monitor, panel, hotkey and menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings: AppSettings
    private let hotKeyRegistrar = HotKeyRegistrar()
    private let systemPasteboard = SystemPasteboard()
    private let pasteCoordinator = PasteCoordinator()
    private let statusMenu: StatusMenuController
    private let settingsWindow: SettingsWindowController
    private var onboardingWindow: OnboardingWindowController?

    private var store: ClipStore?
    private var model: ClipListModel?
    private var monitor: ClipboardMonitor?
    private var panelController: PanelController?
    private var indexer: PictureIndexer?

    override init() {
        let registrar = hotKeyRegistrar
        let settings = AppSettings(
            store: UserDefaults.standard, loginItem: SystemLoginItem(), registerHotKey: { registrar.register($0) }
        )
        self.settings = settings
        statusMenu = StatusMenuController(settings: settings, systemPasteboard: systemPasteboard)
        settingsWindow = SettingsWindowController(settings: settings, setHotKeySuspended: { registrar.isSuspended = $0 })
        super.init()
        statusMenu.showSettingsWindow = { [settingsWindow] in settingsWindow.show() }
        statusMenu.onShowPanel = { [weak self] in self?.panelController?.toggle() }
        settingsWindow.showWelcome = { [weak self] in self?.showWelcome() }
        settingsWindow.onPictureTextEnabled = { [weak self] in self?.indexer?.catchUp() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PreviewOpener.shared.cleanUp()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Leftovers of "Open in Preview" from a run that did not quit cleanly.
        PreviewOpener.shared.cleanUp()
        do {
            try startWithHistory(at: AppPaths.databasePath())
        } catch {
            NSLog("Pastu could not open its database: \(error)")
            statusMenu.storageError = .open
        }

        // The user's shortcut (⇧⌘V by default).
        hotKeyRegistrar.action = { [weak self] in self?.panelController?.toggle() }
        settings.hotKeys.apply()
        if settings.hotKeys.errorMessage != nil { NSLog("Pastu could not register its global hotkey") }

        statusMenu.install()

        // A new install gets the welcome guide, whose second step asks for the Accessibility permission with an
        // explanation. Otherwise ask right away (once per launch) instead of failing silently at the first paste.
        if settings.onboarding.isNeeded {
            showWelcome()
        } else {
            pasteCoordinator.requestAccessibilityIfNeeded()
        }
    }

    // MARK: Starting up

    /// Opens the history and starts everything that works on it.
    private func startWithHistory(at path: String) throws {
        let store = try ClipStore(path: path)
        self.store = store
        try store.prune(settings.retention.policy)
        let model = ClipListModel(store: store)
        self.model = model
        statusMenu.store = store
        statusMenu.model = model
        pasteCoordinator.store = store
        panelController = makePanelController(model: model, store: store)
        let monitor = makeClipboardMonitor(model: model, store: store)
        self.monitor = monitor
        pasteCoordinator.monitor = monitor
        startPictureIndexer(model: model, store: store)
        monitor.start()
    }

    private func makePanelController(model: ClipListModel, store: ClipStore) -> PanelController {
        PanelController(
            model: model,
            canAutoPaste: { PasteSender.isTrusted },
            ignoredApps: settings.ignoredApps,
            imageData: { id in (try? store.imageData(id: id)) ?? nil },
            isPaused: { [recording = settings.recording] in recording.isPaused },
            onResume: { [weak self] in self?.statusMenu.resumeRecording() },
            onCopy: { [weak self] clip in self?.pasteCoordinator.copy(clip) },
            theme: settings.theme,
            queueSettings: settings.queue,
            onPasteQueue: { [weak self] steps in
                Task { @MainActor in await self?.pasteCoordinator.pasteQueue(steps) }
            }
        ) { [weak self] clip in
            self?.pasteCoordinator.paste(clip)
        }
    }

    /// Saves every approved copy, keeps the history within its limits and refreshes an open panel.
    private func makeClipboardMonitor(model: ClipListModel, store: ClipStore) -> ClipboardMonitor {
        let ignoredApps = settings.ignoredApps
        let monitor = ClipboardMonitor(
            source: systemPasteboard,
            filter: PrivacyFilter(ignoredBundleIdentifiers: ignoredApps.bundleIdentifiers),
            recording: settings.recording
        ) { [weak self] clip in
            guard let self else { return }
            do {
                let id = try store.insert(clip)
                if clip.imagePNG != nil { self.indexer?.enqueue(id) }
                try store.prune(self.settings.retention.policy)
                self.statusMenu.storageError = nil
            } catch {
                NSLog("Pastu could not save a clip: \(error)")
                self.statusMenu.storageError = .save
            }
            if self.panelController?.isVisible == true { model.refresh() }
        }
        // Adding or removing an ignored app takes effect for the very next copy.
        ignoredApps.onChange = { [weak monitor] ids in monitor?.filter.ignoredBundleIdentifiers = ids }
        return monitor
    }

    /// Reads the words in pictures in the background so screenshots can be searched. Pictures from before this existed
    /// are caught up a few seconds after launch, so starting Pastu stays quick.
    private func startPictureIndexer(model: ClipListModel, store: ClipStore) {
        let pictureText = settings.pictureText
        let indexer = PictureIndexer(
            store: store, recognizer: VisionTextRecognizer(),
            isEnabled: { pictureText.isEnabled },
            onIndexed: { [weak self] in if self?.panelController?.isVisible == true { model.refresh() } }
        )
        self.indexer = indexer
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            indexer.catchUp()
        }
    }

    // MARK: Welcome guide

    /// Opens the welcome guide from its first step (first launch, or "Show Welcome Guide…" in Settings).
    private func showWelcome() {
        settings.onboarding.restart()
        let controller = onboardingWindow ?? OnboardingWindowController(
            settings: settings,
            isTrusted: { PasteSender.isTrusted },
            requestAccessibility: { [weak self] in self?.pasteCoordinator.requestAccessibilityIfNeeded() },
            openAccessibilitySettings: SystemSettings.openAccessibility
        )
        onboardingWindow = controller
        NSApp.activate()
        _ = controller.show()
    }
}
