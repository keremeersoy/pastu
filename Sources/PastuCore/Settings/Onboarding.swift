import Foundation
import Observation

/// The three-step welcome guide shown on first launch. Remembers only that it was finished.
@MainActor @Observable
public final class Onboarding {
    public enum Step: Int, CaseIterable, Sendable {
        case welcome, pasting, ready

        public var title: String {
            switch self {
            case .welcome: "Welcome to Pastu"
            case .pasting: "Let Pastu paste for you"
            case .ready: "You're all set"
            }
        }
    }

    @ObservationIgnored private let store: SettingsStore?
    public private(set) var step: Step = .welcome
    public private(set) var isNeeded: Bool

    public init(store: SettingsStore? = nil) {
        self.store = store
        isNeeded = !(store?.bool(forKey: DefaultsKeys.onboardingDone) ?? false)
    }

    public var isFirstStep: Bool { step == .welcome }
    public var isLastStep: Bool { step == .ready }

    public func next() {
        if let following = Step(rawValue: step.rawValue + 1) { step = following }
    }

    public func back() {
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    /// Done (or closed): the guide does not open by itself again.
    public func finish() {
        isNeeded = false
        store?.set(true, forKey: DefaultsKeys.onboardingDone)
    }

    /// Shows the guide again from the start, on request. The "done" flag stays set.
    public func restart() {
        step = .welcome
    }
}
