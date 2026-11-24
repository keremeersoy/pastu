import Foundation
import Testing
@testable import PastuCore

@MainActor
@Suite struct OnboardingTests {
    @Test func aNewInstallNeedsTheGuide() {
        #expect(Onboarding(store: InMemorySettings()).isNeeded)
    }

    @Test func finishingItIsRemembered() {
        let settings = InMemorySettings()
        let first = Onboarding(store: settings)
        first.finish()
        #expect(!first.isNeeded)
        #expect(!Onboarding(store: settings).isNeeded)
        #expect(settings.bool(forKey: "onboardingDone"))
    }

    @Test func itStartsOnTheFirstStep() {
        let onboarding = Onboarding()
        #expect(onboarding.step == .welcome)
        #expect(onboarding.isFirstStep)
        #expect(!onboarding.isLastStep)
    }

    @Test func nextAndBackWalkThroughThreeSteps() {
        let onboarding = Onboarding()
        #expect(Onboarding.Step.allCases == [.welcome, .pasting, .ready])
        onboarding.next()
        #expect(onboarding.step == .pasting)
        onboarding.next()
        #expect(onboarding.step == .ready)
        #expect(onboarding.isLastStep)
        onboarding.back()
        #expect(onboarding.step == .pasting)
    }

    @Test func theEndsDoNotWrapAround() {
        let onboarding = Onboarding()
        onboarding.back()
        #expect(onboarding.step == .welcome)
        onboarding.next()
        onboarding.next()
        onboarding.next()
        #expect(onboarding.step == .ready)
    }

    /// "Show Welcome Guide" in Settings opens it again from the start, without marking it needed again.
    @Test func restartingGoesBackToTheFirstStepAndKeepsTheFlag() {
        let settings = InMemorySettings()
        let onboarding = Onboarding(store: settings)
        onboarding.next()
        onboarding.finish()
        onboarding.restart()
        #expect(onboarding.step == .welcome)
        #expect(!onboarding.isNeeded)
        #expect(settings.bool(forKey: "onboardingDone"))
    }

    @Test func titlesAreShort() {
        for step in Onboarding.Step.allCases { #expect(!step.title.isEmpty && step.title.count < 30) }
    }
}
