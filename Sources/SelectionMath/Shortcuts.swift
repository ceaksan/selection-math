import AppKit
import Carbon

enum ShortcutAction: String, CaseIterable, Identifiable {
    case addSelection, captureArea, showPanel
    var id: String { rawValue }
    var titleKey: String { "shortcut.action." + rawValue }
    var hotkeyID: UInt32 { UInt32(Self.allCases.firstIndex(of: self).map { $0 + 1 } ?? 0) }

    init?(hotkeyID: UInt32) {
        guard let action = Self.allCases.first(where: { $0.hotkeyID == hotkeyID }) else { return nil }
        self = action
    }
}

struct Shortcut: Codable, Hashable {
    private static let required = UInt32(cmdKey | controlKey | optionKey)
    private static let supported = UInt32(cmdKey | controlKey | optionKey | shiftKey)
    private static let modifierOrder: [(flag: Int, symbol: String, name: String)] = [
        (controlKey, "⌃", "Control"), (optionKey, "⌥", "Option"), (shiftKey, "⇧", "Shift"), (cmdKey, "⌘", "Command")
    ]
    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]

    static let defaults: [ShortcutAction: Shortcut] = [
        .addSelection: Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey)),
        .captureArea: Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey)),
        .showPanel: Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey))
    ]

    let keyCode: UInt32
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.supported
    }

    init(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        let pairs: [(NSEvent.ModifierFlags, Int)] = [(.control, controlKey), (.option, optionKey), (.shift, shiftKey), (.command, cmdKey)]
        let modifiers = pairs.reduce(UInt32(0)) { flags.contains($1.0) ? $0 | UInt32($1.1) : $0 }
        self.init(keyCode: UInt32(keyCode), modifiers: modifiers)
    }

    var hasRequiredModifier: Bool { modifiers & Self.required != 0 }
    var isValidKey: Bool { keyCode < 128 && modifiers & ~Self.supported == 0 }

    func parts(layout: TISInputSource?) -> [String] {
        Self.modifierOrder.filter { modifiers & UInt32($0.flag) != 0 }.map(\.symbol) + [keyLabel(layout: layout)]
    }

    func symbols(layout: TISInputSource?) -> String { parts(layout: layout).joined() }

    func spoken(layout: TISInputSource?) -> String {
        (Self.modifierOrder.filter { modifiers & UInt32($0.flag) != 0 }.map(\.name) + [keyLabel(layout: layout)])
            .joined(separator: " + ")
    }

    private func keyLabel(layout: TISInputSource?) -> String {
        if let name = Self.namedKeys[Int(keyCode)] { return name }
        if keyCode < 128, let layout, let character = KeyboardLayout.character(keyCode: UInt16(keyCode), carbonModifiers: 0, layout: layout),
           !character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return character.uppercased()
        }
        return "#\(keyCode)"
    }
}

enum ShortcutIssue: Equatable {
    case needsModifier, invalidKey, duplicate(ShortcutAction)
}

enum ShortcutStore {
    static let key = "shortcuts.v1"

    static func load(from defaults: UserDefaults) -> [ShortcutAction: Shortcut] {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode([String: Shortcut].self, from: data) else { return Shortcut.defaults }
        var shortcuts = Shortcut.defaults
        for action in ShortcutAction.allCases {
            if let shortcut = stored[action.rawValue], shortcut.isValidKey, shortcut.hasRequiredModifier {
                shortcuts[action] = shortcut
            }
        }
        return Set(shortcuts.values).count == shortcuts.count ? shortcuts : Shortcut.defaults
    }

    static func save(_ shortcuts: [ShortcutAction: Shortcut], to defaults: UserDefaults) {
        let stored = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        defaults.set(try? JSONEncoder().encode(stored), forKey: key)
    }

    static func validate(_ shortcut: Shortcut, for action: ShortcutAction,
                         in shortcuts: [ShortcutAction: Shortcut]) -> ShortcutIssue? {
        guard shortcut.isValidKey else { return .invalidKey }
        guard shortcut.hasRequiredModifier else { return .needsModifier }
        if let other = ShortcutAction.allCases.first(where: { $0 != action && shortcuts[$0] == shortcut }) {
            return .duplicate(other)
        }
        return nil
    }
}
