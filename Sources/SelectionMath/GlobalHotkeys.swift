import Carbon

@MainActor
final class GlobalHotkeys {
    struct SystemCalls {
        var install: (EventHandlerUPP, UnsafeMutableRawPointer) -> EventHandlerRef?
        var register: (Shortcut, EventHotKeyID) -> EventHotKeyRef?
        var unregister: (EventHotKeyRef) -> Void
        var removeHandler: (EventHandlerRef) -> Void

        static let live = SystemCalls(
            install: { callback, context in
                let events = [
                    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
                ]
                var handler: EventHandlerRef?
                let status = InstallEventHandler(GetApplicationEventTarget(), callback, events.count, events, context, &handler)
                return status == noErr ? handler : nil
            },
            register: { shortcut, hotkey in
                var registration: EventHotKeyRef?
                let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotkey,
                                                 GetApplicationEventTarget(), 0, &registration)
                return status == noErr ? registration : nil
            },
            unregister: { UnregisterEventHotKey($0) },
            removeHandler: { RemoveEventHandler($0) }
        )
    }

    var action: ((ShortcutAction) -> Void)?
    private let system: SystemCalls
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    private var pressed: Set<UInt32> = []

    init(system: SystemCalls = .live) { self.system = system }

    @discardableResult
    func register(_ shortcuts: [ShortcutAction: Shortcut]) -> [ShortcutAction] {
        unregisterAll()
        guard installHandler() else { return ShortcutAction.allCases }
        var failed: [ShortcutAction] = []
        for action in ShortcutAction.allCases {
            guard let shortcut = shortcuts[action] else { continue }
            let hotkey = EventHotKeyID(signature: 0x534D4154, id: action.hotkeyID)
            if let registration = system.register(shortcut, hotkey) {
                registrations.append(registration)
            } else { failed.append(action) }
        }
        return failed
    }

    func unregisterAll() {
        registrations.forEach(system.unregister)
        registrations.removeAll()
        pressed.removeAll()
    }

    func stop() {
        unregisterAll()
        if let handler { system.removeHandler(handler) }
        handler = nil
    }

    private func installHandler() -> Bool {
        guard handler == nil else { return true }
        handler = system.install({ _, event, context in
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
        }, Unmanaged.passUnretained(self).toOpaque())
        return handler != nil
    }

    private func receive(id: UInt32, isPressed: Bool) {
        if isPressed {
            if pressed.insert(id).inserted, let action = ShortcutAction(hotkeyID: id) { self.action?(action) }
        } else { pressed.remove(id) }
    }
}
