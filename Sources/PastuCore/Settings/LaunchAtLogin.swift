import Foundation
import Observation

/// Where the app stands as a login item, independent of the system framework behind it.
public enum LoginItemStatus: Sendable, Equatable {
    case disabled
    case enabled
    /// Registered, but macOS waits for the user to allow it in System Settings → General → Login Items.
    case requiresApproval
    /// The system cannot manage this copy of the app (for example it was not found as an app bundle).
    case unavailable
}

/// What `LaunchAtLogin` needs from the system. The app uses `SMAppService`; tests use a fake and never register
/// the real app.
@MainActor
public protocol LoginItemService: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

/// "Open Pastu at login": the switch in Settings. Nothing is stored by Pastu; macOS is the source of truth, and
/// `refresh()` re-reads it because the user can change it in System Settings at any time.
@MainActor @Observable
public final class LaunchAtLogin {
    @ObservationIgnored private let service: LoginItemService

    public private(set) var status: LoginItemStatus
    /// A short sentence for the user after a failed change, or nil. The system's error is not shown.
    public private(set) var errorMessage: String?

    public init(service: LoginItemService) {
        self.service = service
        status = service.status
    }

    /// On, or waiting for the user's approval in System Settings.
    public var isOn: Bool { status == .enabled || status == .requiresApproval }
    public var needsApproval: Bool { status == .requiresApproval }
    public var isAvailable: Bool { status != .unavailable }

    public func refresh() {
        status = service.status
    }

    public func setEnabled(_ enabled: Bool) {
        refresh()
        guard isAvailable, isOn != enabled else { return }
        do {
            if enabled { try service.register() } else { try service.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = enabled
                ? "Pastu couldn't be added to your login items."
                : "Pastu couldn't be removed from your login items."
        }
        refresh()
    }
}
