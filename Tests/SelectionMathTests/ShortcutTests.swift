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
        let system = FakeHotkeySystem()
        let model = AppModel(defaults: defaults, hotkeys: GlobalHotkeys(system: system.calls))
        defer { model.stop() }
        let custom = Shortcut(keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey))
        XCTAssertNil(model.setShortcut(custom, for: .showPanel))
        XCTAssertEqual(model.shortcuts[.showPanel], custom)
        XCTAssertEqual(ShortcutStore.load(from: defaults)[.showPanel], custom)
        XCTAssertEqual(system.activeShortcuts, model.shortcuts)
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

    @MainActor
    func testFailureOfAnotherShortcutRollsBackTheWholeChange() throws {
        let suite = "selectionmath.rollback.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let system = FakeHotkeySystem()
        let model = AppModel(defaults: defaults, hotkeys: GlobalHotkeys(system: system.calls))
        defer { model.stop() }
        model.resumeShortcuts()
        let custom = Shortcut(keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey | shiftKey))
        system.failOnce = [.addSelection]
        XCTAssertNotNil(model.setShortcut(custom, for: .showPanel))
        XCTAssertEqual(model.shortcuts, Shortcut.defaults)
        XCTAssertEqual(ShortcutStore.load(from: defaults), Shortcut.defaults)
        XCTAssertEqual(system.activeShortcuts, Shortcut.defaults)
    }

    @MainActor
    func testDefaultResetFailurePreservesCustomSettingsAndRegistrations() throws {
        let suite = "selectionmath.reset-shortcuts.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let system = FakeHotkeySystem()
        let model = AppModel(defaults: defaults, hotkeys: GlobalHotkeys(system: system.calls))
        defer { model.stop() }
        let custom = Shortcut(keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey | shiftKey))
        XCTAssertNil(model.setShortcut(custom, for: .showPanel))
        let previous = model.shortcuts
        system.failOnce = [.captureArea]
        XCTAssertNotNil(model.resetShortcuts())
        XCTAssertEqual(model.shortcuts, previous)
        XCTAssertEqual(ShortcutStore.load(from: defaults), previous)
        XCTAssertEqual(system.activeShortcuts, previous)
        XCTAssertNil(model.resetShortcuts())
        XCTAssertEqual(model.shortcuts, Shortcut.defaults)
        XCTAssertEqual(ShortcutStore.load(from: defaults), Shortcut.defaults)
        XCTAssertEqual(system.activeShortcuts, Shortcut.defaults)
    }

    @MainActor
    func testFailedRollbackReportsUnavailableWithoutPersistingTheChange() throws {
        let suite = "selectionmath.failed-rollback.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let system = FakeHotkeySystem()
        let model = AppModel(defaults: defaults, hotkeys: GlobalHotkeys(system: system.calls))
        defer { model.stop() }
        model.resumeShortcuts()
        system.failAlways = [.addSelection]
        let custom = Shortcut(keyCode: UInt32(kVK_F19), modifiers: UInt32(cmdKey | shiftKey))
        XCTAssertEqual(model.setShortcut(custom, for: .showPanel), L("shortcut.unavailable"))
        XCTAssertTrue(model.isError)
        XCTAssertEqual(model.message, L("shortcut.unavailable"))
        XCTAssertEqual(model.shortcuts, Shortcut.defaults)
        XCTAssertEqual(ShortcutStore.load(from: defaults), Shortcut.defaults)
        XCTAssertNil(system.activeShortcuts[.addSelection])
        XCTAssertEqual(system.activeShortcuts[.showPanel], Shortcut.defaults[.showPanel])
    }
}

@MainActor
private final class FakeHotkeySystem {
    var failOnce: Set<ShortcutAction> = []
    var failAlways: Set<ShortcutAction> = []
    private var nextID = 100
    private var active: [EventHotKeyRef: (ShortcutAction, Shortcut)] = [:]

    var activeShortcuts: [ShortcutAction: Shortcut] {
        Dictionary(uniqueKeysWithValues: active.values.map { ($0.0, $0.1) })
    }

    var calls: GlobalHotkeys.SystemCalls {
        GlobalHotkeys.SystemCalls(
            install: { _, _ in OpaquePointer(bitPattern: 1) },
            register: { [self] shortcut, id in
                guard let action = ShortcutAction(hotkeyID: id.id),
                      failOnce.remove(action) == nil, !failAlways.contains(action) else { return nil }
                nextID += 1
                let ref = OpaquePointer(bitPattern: nextID)!
                active[ref] = (action, shortcut)
                return ref
            },
            unregister: { [self] ref in active.removeValue(forKey: ref) },
            removeHandler: { _ in }
        )
    }
}
