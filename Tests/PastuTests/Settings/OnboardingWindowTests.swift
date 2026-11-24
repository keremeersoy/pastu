import AppKit
import Testing
@testable import Pastu
@testable import PastuCore

extension ShellTests {
@MainActor
@Suite struct OnboardingWindowTests {
    private final class Calls {
        var requested = 0
        var openedSettings = 0
        var trusted = false
    }

    private func make(
        _ calls: Calls = Calls(), store: SettingsStore = InMemorySettings(), loginStatus: LoginItemStatus = .disabled
    ) -> (OnboardingWindowController, Onboarding) {
        let settings = AppSettings(store: store, loginItem: StubLoginItem(status: loginStatus), registerHotKey: { _ in true })
        let controller = OnboardingWindowController(
            settings: settings,
            isTrusted: { calls.trusted },
            requestAccessibility: { calls.requested += 1 },
            openAccessibilitySettings: { calls.openedSettings += 1 }
        )
        return (controller, settings.onboarding)
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(300)) }

    private func press(_ text: String, in window: NSWindow) throws {
        let content = try #require(window.contentView)
        let button = try #require(accessibilityElement(containing: text, in: content), "no button \(text)")
        #expect(accessibilityPress(button), "could not press \(text)")
    }

    private func shows(_ text: String, in window: NSWindow) -> Bool {
        window.contentView.map { accessibilityElement(containing: text, in: $0) != nil } ?? false
    }

    @Test func showOpensTheWelcomeStep() async throws {
        enableAccessibilityTree()
        let (controller, _) = make()
        let window = try #require(controller.show())
        defer { window.close() }
        try await settle()
        #expect(window.title == "Pastu")
        #expect(shows("Welcome to Pastu", in: window))
        #expect(shows("⇧⌘V", in: window))
        #expect(!shows("Back", in: window))
    }

    @Test func showingTwiceKeepsOneWindow() throws {
        let (controller, _) = make()
        let window = try #require(controller.show())
        defer { window.close() }
        #expect(controller.show() == nil)
    }

    @Test func continueWalksToThePastingStepAndBack() async throws {
        enableAccessibilityTree()
        let (controller, onboarding) = make()
        let window = try #require(controller.show())
        defer { window.close() }
        try await settle()
        try press("Continue", in: window)
        try await settle()
        #expect(onboarding.step == .pasting)
        #expect(shows("Let Pastu paste for you", in: window))
        try press("Back", in: window)
        try await settle()
        #expect(onboarding.step == .welcome)
    }

    @Test func thePastingStepAsksForAccessWhenNotTrusted() async throws {
        enableAccessibilityTree()
        let calls = Calls()
        let (controller, onboarding) = make(calls)
        onboarding.next()
        let window = try #require(controller.show())
        defer { window.close() }
        try await settle()
        #expect(!shows("Pastu can paste for you", in: window))
        try press("Allow Access", in: window)
        #expect(calls.requested == 1)
        try press("Open System Settings", in: window)
        #expect(calls.openedSettings == 1)
    }

    @Test func thePastingStepConfirmsWhenTrusted() async throws {
        enableAccessibilityTree()
        let calls = Calls()
        calls.trusted = true
        let (controller, onboarding) = make(calls)
        onboarding.next()
        let window = try #require(controller.show())
        defer { window.close() }
        try await settle()
        #expect(shows("Pastu can paste for you", in: window))
        #expect(!shows("Allow Access", in: window))
    }

    @Test func doneOnTheLastStepFinishesAndClosesTheWindow() async throws {
        enableAccessibilityTree()
        let settings = InMemorySettings()
        let (controller, onboarding) = make(store: settings)
        onboarding.next()
        onboarding.next()
        let window = try #require(controller.show())
        try await settle()
        #expect(shows("Open Pastu at login", in: window))
        try press("Done", in: window)
        #expect(!onboarding.isNeeded)
        #expect(!window.isVisible)
        #expect(settings.bool(forKey: "onboardingDone"))
    }

    /// Closing the window with the red button counts as done: the guide must not come back on every launch.
    @Test func closingTheWindowFinishesTheGuide() throws {
        let (controller, onboarding) = make()
        let window = try #require(controller.show())
        window.close()
        #expect(!onboarding.isNeeded)
    }

    /// Whoever opens the guide decides where it starts (Settings restarts it first).
    @Test func showKeepsTheCurrentStep() throws {
        let (controller, onboarding) = make()
        onboarding.next()
        let window = try #require(controller.show())
        defer { window.close() }
        #expect(onboarding.step == .pasting)
    }

    // MARK: Open at login on the last step

    @Test func theLastStepOffersOpenAtLoginAsAWorkingToggle() async throws {
        enableAccessibilityTree()
        let (controller, onboarding) = make(loginStatus: .disabled)
        onboarding.next(); onboarding.next()
        let window = try #require(controller.show())
        defer { window.close() }
        try await settle()
        let content = try #require(window.contentView)
        let toggle = try #require(accessibilityElement(containing: "Open Pastu at login", in: content))
        #expect(toggle.isAccessibilityEnabled?() ?? true, "the switch must be usable when the app can be managed")
        #expect(!shows("isn't available", in: window))
    }

    /// A copy outside /Applications cannot be a login item. The step must say so instead of showing a dead switch.
    @Test func whenLoginItemsAreUnavailableTheLastStepExplainsWhy() async throws {
        enableAccessibilityTree()
        let (controller, onboarding) = make(loginStatus: .unavailable)
        onboarding.next(); onboarding.next()
        let window = try #require(controller.show())
        defer { window.close() }
        try await settle()
        #expect(shows("isn't available for this copy of Pastu", in: window))
        #expect(shows("Applications folder", in: window))
    }

    @Test func whenMacOSWaitsForApprovalTheLastStepPointsToSystemSettings() async throws {
        enableAccessibilityTree()
        let (controller, onboarding) = make(loginStatus: .requiresApproval)
        onboarding.next(); onboarding.next()
        let window = try #require(controller.show())
        defer { window.close() }
        try await settle()
        #expect(shows("System Settings → General → Login Items", in: window))
    }
}
}
