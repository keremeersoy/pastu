import Foundation
import Observation

/// The user's global shortcut. Registering it with the system is the app's job and is passed in as `register`
/// (it returns false when the combination is taken), so this class stays testable without Carbon.
@MainActor @Observable
public final class HotKeySettings {
    @ObservationIgnored private let store: SettingsStore?
    @ObservationIgnored private let register: @MainActor (HotKeyCombo) -> Bool
    @ObservationIgnored private var needsRegistration = false

    public private(set) var combo: HotKeyCombo
    /// A short sentence after a refused or failed change, or nil.
    public private(set) var errorMessage: String?

    /// - Parameter register: registers the combination system-wide, replacing the previous one.
    public init(store: SettingsStore? = nil, register: @escaping @MainActor (HotKeyCombo) -> Bool) {
        self.store = store
        self.register = register
        let stored = store?.string(forKey: DefaultsKeys.hotKey).flatMap(HotKeyCombo.init(storageValue:))
        // A stored combination that is no longer allowed is dropped rather than registered.
        combo = stored.flatMap { $0.problem == nil ? $0 : nil } ?? .default
    }

    /// Registers the current combination; call once at launch. If another app holds it, the message says so
    /// and the choice is kept, so it works again as soon as that app lets go.
    public func apply() {
        if register(combo) {
            needsRegistration = false
            errorMessage = nil
        } else {
            needsRegistration = true
            errorMessage = Self.takenMessage
        }
    }

    /// Switches to `new` when it is allowed and free. On failure the previous shortcut stays active.
    @discardableResult
    public func set(_ new: HotKeyCombo) -> Bool {
        if new == combo, !needsRegistration { return true }
        if let problem = new.problem {
            errorMessage = problem.message
            return false
        }
        guard register(new) else {
            // Put the old one back: Pastu must never end up without a working shortcut.
            _ = register(combo)
            errorMessage = Self.takenMessage
            return false
        }
        combo = new
        needsRegistration = false
        errorMessage = nil
        store?.set(new.storageValue, forKey: DefaultsKeys.hotKey)
        return true
    }

    public func reset() {
        set(.default)
    }

    private static let takenMessage = "That shortcut is already used by another app or by macOS."
}
