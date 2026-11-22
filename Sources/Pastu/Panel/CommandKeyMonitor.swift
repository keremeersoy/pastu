import AppKit
import Observation

/// Tracks whether ⌘ is held while the panel is open, so every row can show its ⌘1–⌘9 badge.
/// The local `flagsChanged` monitor exists only between `start()` and `stop()`: an always-on monitor would
/// watch every modifier press the app ever sees for no reason.
@MainActor
@Observable
final class CommandKeyMonitor {
    /// Settable so snapshot tests can render the held state without a key event.
    var isCommandHeld: Bool
    @ObservationIgnored private var monitor: Any?

    var isMonitoring: Bool { monitor != nil }

    init(isCommandHeld: Bool = false) {
        self.isCommandHeld = isCommandHeld
    }

    /// Call when the panel appears. Picks up a ⌘ that was already down when the panel opened.
    func start() {
        guard monitor == nil else { return }
        isCommandHeld = NSEvent.modifierFlags.contains(.command)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            // Local monitors run on the main thread.
            MainActor.assumeIsolated { self?.update(event.modifierFlags) }
            return event
        }
    }

    /// Call when the panel hides; also clears the held state so the next open does not start with badges on.
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isCommandHeld = false
    }

    private func update(_ flags: NSEvent.ModifierFlags) {
        let held = flags.contains(.command)
        if held != isCommandHeld { isCommandHeld = held }
    }
}
