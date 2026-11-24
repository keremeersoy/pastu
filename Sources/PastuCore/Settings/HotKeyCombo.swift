import Foundation

/// A global shortcut: a key plus modifiers. The key is a hardware key code (the US layout names are used for
/// display, and only keys with a name are accepted, so what is shown is what the user pressed).
public struct HotKeyCombo: Equatable, Sendable {
    public struct Modifiers: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)

        /// Carbon's `cmdKey`, `shiftKey`, `optionKey` and `controlKey`, which `RegisterEventHotKey` wants.
        public var carbonValue: Int {
            (contains(.command) ? 0x100 : 0) | (contains(.shift) ? 0x200 : 0)
                | (contains(.option) ? 0x800 : 0) | (contains(.control) ? 0x1000 : 0)
        }
    }

    /// Why a combination cannot be used. `message` is the sentence shown to the user.
    public enum Problem: Sendable {
        case needsModifier, collidesWithAppShortcuts, reservedBySystem, unsupportedKey

        public var message: String {
            switch self {
            case .needsModifier: "Hold ⌘, ⌥ or ⌃ together with the key."
            case .collidesWithAppShortcuts: "⌘ alone would take over a shortcut that apps use. Add ⇧, ⌥ or ⌃."
            case .reservedBySystem: "macOS uses that shortcut."
            case .unsupportedKey: "Pick a letter, a digit, Space or an F key."
            }
        }
    }

    public var keyCode: Int
    public var modifiers: Modifiers

    public init(keyCode: Int, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let `default` = HotKeyCombo(keyCode: 9, modifiers: [.command, .shift])

    public var carbonModifiers: Int { modifiers.carbonValue }

    // MARK: Names

    /// Hardware key codes of the ANSI layout. Letters, digits, Space and F1–F12 only.
    private static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
        13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J",
        40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        49: "Space",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12",
    ]

    public var keyName: String? { Self.keyNames[keyCode] }

    private var isFunctionKey: Bool { keyName?.first == "F" && (keyName?.count ?? 0) > 1 }

    /// "⌃⌥⇧⌘V": modifiers in the order macOS menus use, then the key.
    public var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + (keyName ?? "?")
    }

    /// What a menu item needs to show this shortcut next to its title; nil for F keys, which have no plain character.
    public var menuKeyEquivalent: String? {
        guard let name = keyName, !isFunctionKey else { return nil }
        return name == "Space" ? " " : name.lowercased()
    }

    // MARK: Validation

    public var problem: Problem? {
        guard !modifiers.isDisjoint(with: [.command, .option, .control]) else { return .needsModifier }
        guard keyName != nil else { return .unsupportedKey }
        // Spotlight (⌘Space), the input source switch (⌃Space) and Finder search (⌘⌥Space).
        if keyName == "Space", [Modifiers.command, .control, [.command, .option]].contains(modifiers) {
            return .reservedBySystem
        }
        // Carbon would swallow ⌘C, ⌘V, ⌘Q… in every app.
        if modifiers == .command, !isFunctionKey { return .collidesWithAppShortcuts }
        return nil
    }

    // MARK: Storage

    /// "keyCode:modifierBits", the format kept in the settings store (pinned by tests).
    public var storageValue: String { "\(keyCode):\(modifiers.rawValue)" }

    public init?(storageValue: String) {
        let parts = storageValue.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let code = Int(parts[0]), code >= 0, let bits = Int(parts[1]),
              bits > 0, bits <= 0b1111 else { return nil }
        self.init(keyCode: code, modifiers: Modifiers(rawValue: bits))
    }
}
