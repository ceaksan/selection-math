import Foundation

public struct ClipboardSnapshot {
    public static let concealedType = "org.nspasteboard.ConcealedType"
    public let items: [[String: Data]]
    public let revision: Int

    public init(items: [[String: Data]], revision: Int) {
        self.items = items
        self.revision = revision
    }

    public var isConcealed: Bool { items.contains { $0[Self.concealedType] != nil } }
}

@MainActor
public protocol SelectionTransferIO {
    var sourceName: String { get }
    var sourceIsActive: Bool { get }
    var clipboardRevision: Int { get }
    func selectedText() async -> String?
    func snapshotClipboard() throws -> ClipboardSnapshot
    func copySelection() throws
    func clipboardText() -> String?
    func restoreClipboard(_ snapshot: ClipboardSnapshot, replacing revision: Int) -> Bool
    func waitForCopy() async
}

public struct CaptureOutcome: Equatable {
    public let accepted: Bool
    public let skipped: [String]
    public let clipboardRestored: Bool
}

public enum TransferError: String, Error {
    case noSelection, sourceChanged, clipboardUnavailable, concealedClipboard, busy
}

@MainActor
public final class SelectionTransfer {
    public static let copyAttempts = 75
    private let session: CalculatorSession
    private var busy = false

    public init(session: CalculatorSession) { self.session = session }

    @discardableResult
    public func capture(using io: any SelectionTransferIO) async throws -> CaptureOutcome {
        guard !busy else { throw TransferError.busy }
        busy = true
        defer { busy = false }
        let generation = session.generation
        guard io.sourceIsActive else { throw TransferError.sourceChanged }
        let selected = await io.selectedText()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text: String
        var restored = true
        if let selected, !selected.isEmpty {
            text = selected
        } else {
            (text, restored) = try await copiedSelection(using: io)
        }
        guard io.sourceIsActive else { throw TransferError.sourceChanged }
        let acceptance = try session.accept(text, source: io.sourceName, generation: generation)
        return CaptureOutcome(accepted: acceptance.accepted, skipped: acceptance.skipped, clipboardRestored: restored)
    }

    private func copiedSelection(using io: any SelectionTransferIO) async throws -> (text: String, restored: Bool) {
        guard io.sourceIsActive else { throw TransferError.sourceChanged }
        let snapshot = try io.snapshotClipboard()
        guard !snapshot.isConcealed else { throw TransferError.concealedClipboard }
        guard io.clipboardRevision == snapshot.revision else { throw TransferError.clipboardUnavailable }
        try io.copySelection()
        var observed: Int?
        for _ in 0..<Self.copyAttempts {
            await io.waitForCopy()
            guard io.sourceIsActive else { throw TransferError.sourceChanged }
            let revision = io.clipboardRevision
            guard revision != snapshot.revision else { continue }
            if let observed, observed != revision { throw TransferError.clipboardUnavailable }
            observed = revision
            guard let text = io.clipboardText(), !text.isEmpty else { continue }
            guard io.clipboardRevision == revision else { throw TransferError.clipboardUnavailable }
            return (text, io.restoreClipboard(snapshot, replacing: revision))
        }
        if let observed, io.clipboardRevision == observed { _ = io.restoreClipboard(snapshot, replacing: observed) }
        throw TransferError.noSelection
    }
}
