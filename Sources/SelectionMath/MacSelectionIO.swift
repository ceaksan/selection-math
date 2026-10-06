import AppKit
import ApplicationServices
import Carbon
import MathCore

@MainActor
final class MacSelectionIO: SelectionTransferIO {
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    let sourceName: String
    private let pid: pid_t
    private let pasteboard: NSPasteboard

    init(application: NSRunningApplication, pasteboard: NSPasteboard = .general) {
        pid = application.processIdentifier
        sourceName = application.localizedName ?? L("source.selection")
        self.pasteboard = pasteboard
    }

    var sourceIsActive: Bool { NSWorkspace.shared.frontmostApplication?.processIdentifier == pid }
    var clipboardRevision: Int { pasteboard.changeCount }

    func selectedText() async -> String? {
        let target = pid
        return await Task.detached(priority: .userInitiated) { SelectionReader.read(pid: target)?.text }.value
    }

    func snapshotClipboard() throws -> ClipboardSnapshot {
        let revision = pasteboard.changeCount
        var bytes = 0
        var items: [[String: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var contents: [String: Data] = [:]
            for type in item.types {
                guard let data = item.data(forType: type) else { throw TransferError.clipboardUnavailable }
                bytes += data.count
                guard bytes <= 20_000_000 else { throw TransferError.clipboardUnavailable }
                contents[type.rawValue] = data
            }
            items.append(contents)
        }
        guard pasteboard.changeCount == revision else { throw TransferError.clipboardUnavailable }
        return ClipboardSnapshot(items: items, revision: revision)
    }

    func copySelection() throws {
        guard sourceIsActive else { throw TransferError.sourceChanged }
        let key = Self.copyKeyCode(layout: KeyboardLayout.current())
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            throw TransferError.clipboardUnavailable
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
    }

    func clipboardText() -> String? { pasteboard.string(forType: .string) }

    func restoreClipboard(_ snapshot: ClipboardSnapshot, replacing revision: Int) -> Bool {
        let items = snapshot.items.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
            item.setData(Data(), forType: Self.transientType)
            return item
        }
        guard pasteboard.changeCount == revision else { return false }
        pasteboard.clearContents()
        return items.isEmpty || pasteboard.writeObjects(items)
    }

    nonisolated static func copyKeyCode(layout: TISInputSource?) -> UInt16 {
        layout.flatMap { KeyboardLayout.keyCode(for: "c", carbonModifiers: UInt32(cmdKey), layout: $0) }
            ?? UInt16(kVK_ANSI_C)
    }

    func waitForCopy() async { try? await Task.sleep(nanoseconds: 20_000_000) }
}
