import AppKit
import Observation
import PastuCore

extension HotKeyCombo.Modifiers {
    /// Only the four modifiers a shortcut can use; Caps Lock, Fn and the numeric-pad flag are dropped.
    init(cocoa flags: NSEvent.ModifierFlags) {
        var result: HotKeyCombo.Modifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        self = result
    }

    var cocoa: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.shift) { flags.insert(.shift) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        return flags
    }
}

/// "Click, then press the new shortcut." While recording, the current global shortcut is suspended and the next key
/// press (Esc cancels) is taken as the new one.
@MainActor @Observable
final class ShortcutRecorder {
    private(set) var isRecording = false

    @ObservationIgnored private let hotKeys: HotKeySettings
    @ObservationIgnored private let installMonitor: Bool
    @ObservationIgnored private let setSuspended: (Bool) -> Void
    @ObservationIgnored private var monitor: Any?

    /// - Parameter installMonitor: false in tests, which call `handle` directly.
    /// - Parameter setSuspended: tells the global shortcut to stand down (true) or work again (false).
    init(hotKeys: HotKeySettings, installMonitor: Bool = true, setSuspended: @escaping (Bool) -> Void) {
        self.hotKeys = hotKeys
        self.installMonitor = installMonitor
        self.setSuspended = setSuspended
    }

    func start() {
        guard !isRecording else { return }
        isRecording = true
        setSuspended(true)
        guard installMonitor else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let code = Int(event.keyCode)
            let flags = event.modifierFlags
            let consumed = MainActor.assumeIsolated { self?.handle(keyCode: code, flags: flags) ?? false }
            return consumed ? nil : event
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        setSuspended(false)
    }

    /// Returns true when the key press was used up (the recorder was listening).
    func handle(keyCode: Int, flags: NSEvent.ModifierFlags) -> Bool {
        guard isRecording else { return false }
        // Stand down first, so the new shortcut is registered while nothing is suspended.
        stop()
        guard keyCode != 53 else { return true }   // Esc
        hotKeys.set(HotKeyCombo(keyCode: keyCode, modifiers: .init(cocoa: flags)))
        return true
    }
}
