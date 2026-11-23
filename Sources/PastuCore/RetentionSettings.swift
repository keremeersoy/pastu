import Foundation
import Observation

/// One retention limit: a number in the limit's own unit, or none.
public enum RetentionLimit: Hashable, Sendable {
    case limited(Int)
    case unlimited

    fileprivate var storageValue: String {
        switch self {
        case .limited(let value): String(value)
        case .unlimited: "unlimited"
        }
    }

    fileprivate init?(storageValue: String, among choices: [RetentionLimit]) {
        // Only an offered choice is accepted: anything else would be a hand-edited or foreign value.
        guard let match = choices.first(where: { $0.storageValue == storageValue }) else { return nil }
        self = match
    }
}

/// How much history to keep, chosen from fixed lists in Settings. Persisted in a `SettingsStore`.
/// The limits apply the next time Pastu saves a clip or starts; pinned clips are never deleted.
@MainActor @Observable
public final class RetentionSettings {
    public static let countChoices: [RetentionLimit] = [.limited(500), .limited(1_000), .limited(5_000), .limited(10_000), .unlimited]
    /// Days.
    public static let ageChoices: [RetentionLimit] = [.limited(7), .limited(30), .limited(90), .limited(365), .unlimited]
    /// Megabytes of estimated database size.
    public static let sizeChoices: [RetentionLimit] = [.limited(50), .limited(200), .limited(500), .limited(1_024), .unlimited]

    @ObservationIgnored private let store: SettingsStore?

    public var count: RetentionLimit {
        didSet { store?.set(count.storageValue, forKey: DefaultsKeys.retentionCount) }
    }

    public var age: RetentionLimit {
        didSet { store?.set(age.storageValue, forKey: DefaultsKeys.retentionAgeDays) }
    }

    public var size: RetentionLimit {
        didSet { store?.set(size.storageValue, forKey: DefaultsKeys.retentionSizeMB) }
    }

    /// - Parameter store: where to persist the choices, or `nil` to keep them only in this object.
    public init(store: SettingsStore? = nil) {
        self.store = store
        func load(_ key: String, _ choices: [RetentionLimit], default fallback: RetentionLimit) -> RetentionLimit {
            store?.string(forKey: key).flatMap { RetentionLimit(storageValue: $0, among: choices) } ?? fallback
        }
        count = load(DefaultsKeys.retentionCount, Self.countChoices, default: .limited(5_000))
        age = load(DefaultsKeys.retentionAgeDays, Self.ageChoices, default: .limited(90))
        size = load(DefaultsKeys.retentionSizeMB, Self.sizeChoices, default: .limited(200))
    }

    /// The policy to prune with, read each time the history is pruned.
    public var policy: RetentionPolicy {
        RetentionPolicy(
            maxCount: value(of: count),
            maxAge: value(of: age).map { TimeInterval($0) * 24 * 3600 },
            maxTotalBytes: value(of: size).map { $0 * 1024 * 1024 }
        )
    }

    private func value(of limit: RetentionLimit) -> Int? {
        if case .limited(let value) = limit { value } else { nil }
    }

    // MARK: Titles

    public static func countTitle(_ limit: RetentionLimit) -> String {
        guard case .limited(let value) = limit else { return "No limit" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        return "\(formatter.string(from: NSNumber(value: value)) ?? String(value)) clips"
    }

    public static func ageTitle(_ limit: RetentionLimit) -> String {
        guard case .limited(let days) = limit else { return "Forever" }
        switch days {
        case 7: return "1 week"
        case 365: return "1 year"
        default: return "\(days) days"
        }
    }

    public static func sizeTitle(_ limit: RetentionLimit) -> String {
        guard case .limited(let megabytes) = limit else { return "No limit" }
        return megabytes == 1_024 ? "1 GB" : "\(megabytes) MB"
    }
}
