import Carbon.HIToolbox

/// A system-wide keyboard shortcut, registered through Carbon's hot-key API.
/// Unlike an event tap, this needs no Accessibility permission and costs
/// nothing while idle: macOS only wakes the app when the shortcut is pressed.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// Returns nil if the shortcut is already taken by another app.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        guard status == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x5343_4C50), id: 1) // "SCLP"
        let registered = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id,
                                             GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            handlerRef = nil
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
