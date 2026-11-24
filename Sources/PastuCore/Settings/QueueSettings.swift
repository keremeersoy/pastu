import Foundation
import Observation

/// What goes between two queued text clips when they are pasted one after another.
public enum QueueSeparator: String, CaseIterable, Sendable {
    case newline, space, tab, none

    public var title: String {
        switch self {
        case .newline: "New line"
        case .space: "Space"
        case .tab: "Tab"
        case .none: "Nothing"
        }
    }

    public var text: String {
        switch self {
        case .newline: "\n"
        case .space: " "
        case .tab: "\t"
        case .none: ""
        }
    }
}

/// The separator choice, persisted in a `SettingsStore`. An unknown stored value means a new line.
@MainActor @Observable
public final class QueueSettings {
    @ObservationIgnored private let store: SettingsStore?

    public var separator: QueueSeparator {
        didSet { store?.set(separator.rawValue, forKey: DefaultsKeys.queueSeparator) }
    }

    public init(store: SettingsStore? = nil) {
        self.store = store
        separator = store?.string(forKey: DefaultsKeys.queueSeparator).flatMap(QueueSeparator.init) ?? .newline
    }
}
