import PastuCore

/// Registers the user's shortcut with the system, replacing the previous one. Pressing it runs `action`,
/// except while Settings is recording a new shortcut (then the keys belong to the recorder).
@MainActor
final class HotKeyRegistrar {
    private var hotKey: GlobalHotKey?
    var action: @MainActor () -> Void = {}
    var isSuspended = false

    /// False when the combination is taken. The previous shortcut is gone either way; `HotKeySettings` restores it.
    func register(_ combo: HotKeyCombo) -> Bool {
        hotKey = nil
        guard let new = GlobalHotKey(keyCode: combo.keyCode, modifiers: combo.carbonModifiers, action: { [weak self] in
            guard let self, !self.isSuspended else { return }
            self.action()
        }) else { return false }
        hotKey = new
        return true
    }
}
