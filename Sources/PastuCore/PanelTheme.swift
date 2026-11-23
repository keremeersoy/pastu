import Foundation

/// Light or dark look of the panel; `system` follows macOS.
public enum PanelAppearance: String, CaseIterable, Sendable {
    case system, light, dark

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// What the panel background is made of. Reduce Transparency in System Settings always wins over this choice;
/// that is decided where the panel is drawn, because the setting can change while Pastu runs.
public enum PanelMaterial: String, CaseIterable, Sendable {
    /// Liquid Glass (macOS 26+).
    case glass
    /// A blurred, translucent background (`NSVisualEffectView`), the look macOS 15 uses.
    case frosted
    /// An opaque background.
    case solid

    public var title: String {
        switch self {
        case .glass: "Liquid Glass"
        case .frosted: "Frosted"
        case .solid: "Solid"
        }
    }

    /// What is actually drawn: a stored Liquid Glass choice becomes Frosted where glass does not exist.
    public func resolved(glassAvailable: Bool) -> PanelMaterial {
        self == .glass && !glassAvailable ? .frosted : self
    }

    /// The materials a menu should offer.
    public static func choices(glassAvailable: Bool) -> [PanelMaterial] {
        allCases.filter { $0 != .glass || glassAvailable }
    }
}

/// The user's panel theme, optionally persisted in a `SettingsStore`.
/// An unknown or missing stored value means the default: system appearance, Liquid Glass.
@MainActor
public final class ThemeSettings {
    private let store: SettingsStore?

    public var appearance: PanelAppearance {
        didSet { store?.set(appearance.rawValue, forKey: DefaultsKeys.panelAppearance) }
    }

    public var material: PanelMaterial {
        didSet { store?.set(material.rawValue, forKey: DefaultsKeys.panelMaterial) }
    }

    /// - Parameter store: where to persist the choices, or `nil` to keep them only in this object.
    public init(store: SettingsStore? = nil) {
        self.store = store
        appearance = store?.string(forKey: DefaultsKeys.panelAppearance).flatMap(PanelAppearance.init) ?? .system
        material = store?.string(forKey: DefaultsKeys.panelMaterial).flatMap(PanelMaterial.init) ?? .glass
    }
}
