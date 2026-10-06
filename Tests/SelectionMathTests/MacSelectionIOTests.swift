import AppKit
import Carbon
import MathCore
import XCTest
@testable import SelectionMath

final class MacSelectionIOTests: XCTestCase {
    func testCopyKeyCodeProducesCOnEveryLayout() throws {
        let command = UInt32(cmdKey)
        for id in ["com.apple.keylayout.US", "com.apple.keylayout.Turkish", "com.apple.keylayout.Turkish-QWERTY-PC",
                   "com.apple.keylayout.Dvorak", "com.apple.keylayout.Russian"] {
            let layout = try XCTUnwrap(KeyboardLayout.installed(id: id), id)
            let code = MacSelectionIO.copyKeyCode(layout: layout)
            XCTAssertEqual(KeyboardLayout.character(keyCode: code, carbonModifiers: command, layout: layout), "c", id)
        }
        let turkishF = try XCTUnwrap(KeyboardLayout.installed(id: "com.apple.keylayout.Turkish"))
        XCTAssertEqual(KeyboardLayout.character(keyCode: 8, carbonModifiers: command, layout: turkishF), "v")
        XCTAssertEqual(MacSelectionIO.copyKeyCode(layout: nil), UInt16(kVK_ANSI_C))
    }

    @MainActor
    func testSnapshotRefusesAnIncompleteBackup() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let provider = SilentProvider()
        let item = NSPasteboardItem()
        item.setString("previous", forType: .string)
        item.setDataProvider(provider, forTypes: [NSPasteboard.PasteboardType("test.unreadable")])
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        XCTAssertThrowsError(try MacSelectionIO(application: .current, pasteboard: pasteboard).snapshotClipboard()) {
            XCTAssertEqual($0 as? TransferError, .clipboardUnavailable)
        }
    }

    @MainActor
    func testSnapshotDetectsConcealedItems() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("secret", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType(ClipboardSnapshot.concealedType))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        XCTAssertTrue(try MacSelectionIO(application: .current, pasteboard: pasteboard).snapshotClipboard().isConcealed)
    }

    @MainActor
    func testRestoreWritesSnapshotAsTransientAndSkipsNewerClipboard() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("previous", forType: .string)
        let io = MacSelectionIO(application: .current, pasteboard: pasteboard)
        let snapshot = try io.snapshotClipboard()
        XCTAssertEqual(try XCTUnwrap(snapshot.items.first)[NSPasteboard.PasteboardType.string.rawValue], Data("previous".utf8))
        XCTAssertFalse(snapshot.isConcealed)
        pasteboard.clearContents()
        pasteboard.setString("copied cell", forType: .string)
        XCTAssertFalse(io.restoreClipboard(snapshot, replacing: pasteboard.changeCount - 1))
        XCTAssertEqual(pasteboard.string(forType: .string), "copied cell")
        XCTAssertTrue(io.restoreClipboard(snapshot, replacing: pasteboard.changeCount))
        XCTAssertEqual(pasteboard.string(forType: .string), "previous")
        XCTAssertTrue(pasteboard.types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) ?? false)
    }

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("selectionmath.test.\(UUID().uuidString)"))
    }
}

private final class SilentProvider: NSObject, NSPasteboardItemDataProvider {
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {}
}
