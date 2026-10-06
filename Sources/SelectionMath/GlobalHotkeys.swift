import Carbon

@MainActor
final class GlobalHotkeys {
    var action: ((ShortcutAction) -> Void)?
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    private var pressed: Set<UInt32> = []

    @discardableResult
    func register(_ shortcuts: [ShortcutAction: Shortcut]) -> [ShortcutAction] {
        unregisterAll()
        guard installHandler() else { return ShortcutAction.allCases }
        var failed: [ShortcutAction] = []
        for action in ShortcutAction.allCases {
            guard let shortcut = shortcuts[action] else { continue }
            var registration: EventHotKeyRef?
            let hotkey = EventHotKeyID(signature: 0x534D4154, id: action.hotkeyID)
            let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotkey,
                                             GetApplicationEventTarget(), 0, &registration)
            if result == noErr, let registration { registrations.append(registration) } else { failed.append(action) }
        }
        return failed
    }

    func unregisterAll() {
        registrations.forEach { UnregisterEventHotKey($0) }
        registrations.removeAll()
        pressed.removeAll()
    }

    func stop() {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    private func installHandler() -> Bool {
        guard handler == nil else { return true }
        let events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                          nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard result == noErr else { return result }
            let owner = Unmanaged<GlobalHotkeys>.fromOpaque(context).takeUnretainedValue()
            let id = key.id
            let isPressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            Task { @MainActor in owner.receive(id: id, isPressed: isPressed) }
            return noErr
        }, events.count, events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        return status == noErr
    }

    private func receive(id: UInt32, isPressed: Bool) {
        if isPressed {
            if pressed.insert(id).inserted, let action = ShortcutAction(hotkeyID: id) { self.action?(action) }
        } else { pressed.remove(id) }
    }
}
