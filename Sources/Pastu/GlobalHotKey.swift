import Carbon.HIToolbox

/// A system-wide hotkey via Carbon's RegisterEventHotKey.
/// It needs no Accessibility permission and no third-party dependency.
@MainActor
final class GlobalHotKey {
    // The Carbon callback is a C function pointer and cannot capture, so the action lives here.
    private static var action: (@MainActor () -> Void)?

    // Only touched on the main thread; `nonisolated(unsafe)` lets the nonisolated deinit clean them up.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?

    /// Returns nil when the hotkey could not be registered (e.g. already taken by another app).
    init?(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        Self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                // Hotkey events are delivered on the main thread.
                MainActor.assumeIsolated { GlobalHotKey.action?() }
                return noErr
            },
            1, &eventType, nil, &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let id = EventHotKeyID(signature: 0x5053_5455 /* 'PSTU' */, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), id,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
