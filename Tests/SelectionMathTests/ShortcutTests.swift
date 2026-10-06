import AppKit
import Carbon
import XCTest
@testable import SelectionMath

final class ShortcutTests: XCTestCase {
    private let controlOption = UInt32(controlKey | optionKey)

    func testDefaultsKeepTheOriginalShortcuts() {
        XCTAssertEqual(Shortcut.defaults[.addSelection], Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: controlOption))
        XCTAssertEqual(Shortcut.defaults[.captureArea], Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: controlOption))
        XCTAssertEqual(Shortcut.defaults[.showPanel], Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: controlOption))
    }

    func testValidationRequiresModifierAndRejectsDuplicates() {
        let defaults = Shortcut.defaults
        let shiftOnly = Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey))
        XCTAssertEqual(ShortcutStore.validate(shiftOnly, for: .addSelection, in: defaults), .needsModifier)
        let captureCombo = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: controlOption)
        XCTAssertEqual(ShortcutStore.validate(captureCombo, for: .addSelection, in: defaults), .duplicate(.captureArea))
        XCTAssertNil(ShortcutStore.validate(captureCombo, for: .captureArea, in: defaults))
        let commandShift = Shortcut(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey | shiftKey))
        XCTAssertNil(ShortcutStore.validate(commandShift, for: .addSelection, in: defaults))
    }

    func testStoreRoundTripsAndFallsBackOnCorruptData() throws {
        let suite = "selectionmath.shortcuts.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var custom = Shortcut.defaults
        custom[.addSelection] = Shortcut(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey | shiftKey))
        ShortcutStore.save(custom, to: defaults)
        XCTAssertEqual(ShortcutStore.load(from: defaults), custom)
        defaults.set(Data("broken".utf8), forKey: ShortcutStore.key)
        XCTAssertEqual(ShortcutStore.load(from: defaults), Shortcut.defaults)
    }

    func testOutOfRangeStoredShortcutsFallBackToDefaults() throws {
        let suite = "selectionmath.shortcuts.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for stored in [#"{"addSelection":{"keyCode":70000,"modifiers":6144}}"#,
                       #"{"addSelection":{"keyCode":0,"modifiers":4294967295}}"#] {
            defaults.set(Data(stored.utf8), forKey: ShortcutStore.key)
            XCTAssertEqual(ShortcutStore.load(from: defaults)[.addSelection], Shortcut.defaults[.addSelection], stored)
        }
        let outOfRange = Shortcut(keyCode: 70000, modifiers: UInt32(cmdKey))
        XCTAssertEqual(ShortcutStore.validate(outOfRange, for: .addSelection, in: Shortcut.defaults), .invalidKey)
    }

    @MainActor
    func testSettingAShortcutThroughTheModelRegistersAndPersistsIt() throws {
        let suite = "selectionmath.model.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        defer { model.stop() }
        let custom = Shortcut(keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey))
        XCTAssertNil(model.setShortcut(custom, for: .showPanel))
        XCTAssertEqual(model.shortcuts[.showPanel], custom)
        XCTAssertEqual(ShortcutStore.load(from: defaults)[.showPanel], custom)
        XCTAssertNotNil(model.setShortcut(custom, for: .addSelection))
        XCTAssertEqual(model.shortcuts[.addSelection], Shortcut.defaults[.addSelection])
        XCTAssertNotNil(model.setShortcut(Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(shiftKey)), for: .captureArea))
        XCTAssertEqual(ShortcutStore.load(from: defaults)[.captureArea], Shortcut.defaults[.captureArea])
    }

    func testLabelsFollowTheKeyboardLayout() throws {
        let us = try XCTUnwrap(KeyboardLayout.installed(id: "com.apple.keylayout.US"))
        let dvorak = try XCTUnwrap(KeyboardLayout.installed(id: "com.apple.keylayout.Dvorak"))
        let add = Shortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: controlOption)
        XCTAssertEqual(add.symbols(layout: us), "⌃⌥A")
        XCTAssertEqual(add.spoken(layout: us), "Control + Option + A")
        let capture = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | shiftKey))
        XCTAssertEqual(capture.symbols(layout: dvorak), "⇧⌘O")
        XCTAssertEqual(Shortcut(keyCode: UInt32(kVK_F5), modifiers: UInt32(cmdKey)).symbols(layout: us), "⌘F5")
    }

    func testEventFlagsConvertToCarbonModifiers() {
        let shortcut = Shortcut(keyCode: UInt16(kVK_ANSI_K), flags: [.command, .shift, .capsLock])
        XCTAssertEqual(shortcut.modifiers, UInt32(cmdKey | shiftKey))
        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_K))
    }
}
