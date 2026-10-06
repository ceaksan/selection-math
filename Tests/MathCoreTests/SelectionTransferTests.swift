import XCTest
@testable import MathCore

final class SelectionTransferTests: XCTestCase {
    @MainActor
    func testCanvasCellIsTransferredWithoutSelectedText() async throws {
        let session = CalculatorSession()
        let transfer = SelectionTransfer(session: session)
        let io = FakeSelectionIO()
        io.copiedText = "310,872"
        try await transfer.capture(using: io)
        XCTAssertEqual(try session.result().value, 310872)
        XCTAssertEqual(io.copyCount, 1)
        XCTAssertEqual(io.currentText, "previous clipboard")
        XCTAssertEqual(io.restoreCount, 1)
    }

    @MainActor
    func testTextSelectionDoesNotTouchClipboard() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.exposedText = "120 | 80"
        try await SelectionTransfer(session: session).capture(using: io)
        XCTAssertEqual(try session.result().value, 200)
        XCTAssertEqual(io.copyCount, 0)
        XCTAssertEqual(io.clipboardRevision, 10)
    }

    @MainActor
    func testShortcutKeepsDecimalAndIndependentEqualSelections() async throws {
        let session = CalculatorSession()
        session.style = .turkish
        let transfer = SelectionTransfer(session: session)
        let io = FakeSelectionIO()
        io.copiedText = "5.60"
        try await transfer.capture(using: io)
        io.copiedText = "5.60"
        try await transfer.capture(using: io)
        XCTAssertEqual(session.operands.count, 2)
        XCTAssertEqual(try session.result().value, Decimal(string: "11.2"))
        XCTAssertEqual(io.currentText, "previous clipboard")
    }

    @MainActor
    func testResetDuringCopyRestoresClipboardWithoutAddingStaleData() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.copiedText = "999"
        io.onWait = { session.reset() }
        let outcome = try await SelectionTransfer(session: session).capture(using: io)
        XCTAssertFalse(outcome.accepted)
        XCTAssertTrue(session.operands.isEmpty)
        XCTAssertEqual(io.currentText, "previous clipboard")
    }

    @MainActor
    func testCopyTimeoutDoesNotReadOldClipboardNumbers() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.currentText = "12345"
        do {
            try await SelectionTransfer(session: session).capture(using: io)
            XCTFail("Unchanged clipboard must not become a new selection")
        } catch { XCTAssertEqual(error as? TransferError, .noSelection) }
        XCTAssertTrue(session.operands.isEmpty)
        XCTAssertEqual(io.currentText, "12345")
        XCTAssertEqual(io.restoreCount, 0)
    }

    @MainActor
    func testInvalidCopyStillRestoresClipboardAndLeavesOperandsUntouched() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.copiedText = "nothing numeric"
        do {
            try await SelectionTransfer(session: session).capture(using: io)
            XCTFail("Non-numeric cells must not be added")
        } catch { XCTAssertEqual(error as? MathError, .noNumbers) }
        XCTAssertTrue(session.operands.isEmpty)
        XCTAssertEqual(io.currentText, "previous clipboard")
    }

    @MainActor
    func testFocusChangePreventsCopyFromAnotherApp() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.sourceIsActive = false
        do {
            try await SelectionTransfer(session: session).capture(using: io)
            XCTFail("Must not copy from a different app")
        } catch { XCTAssertEqual(error as? TransferError, .sourceChanged) }
        XCTAssertEqual(io.copyCount, 0)
    }

    @MainActor
    func testNonTextCopyRestoresPreviousClipboard() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.copiesNonText = true
        do {
            try await SelectionTransfer(session: session).capture(using: io)
            XCTFail("Non-text copy must not add numbers")
        } catch { XCTAssertEqual(error as? TransferError, .noSelection) }
        XCTAssertEqual(io.restoreCount, 1)
        XCTAssertEqual(io.clipboardText(), "previous clipboard")
        XCTAssertTrue(session.operands.isEmpty)
    }

    @MainActor
    func testSlowCopyWithinTimeoutIsAcceptedAndRestored() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.copiedText = "42"
        io.copyDelay = 40
        try await SelectionTransfer(session: session).capture(using: io)
        XCTAssertEqual(try session.result().value, 42)
        XCTAssertEqual(io.currentText, "previous clipboard")
        XCTAssertEqual(io.restoreCount, 1)
    }

    @MainActor
    func testSecondClipboardWriteAbortsWithoutRestoring() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.copiesNonText = true
        io.onWaitNumber = { count in
            if count == 3 { io.holdsNonText = false; io.currentText = "987654"; io.clipboardRevision += 1 }
        }
        do {
            try await SelectionTransfer(session: session).capture(using: io)
            XCTFail("An unverified clipboard write must not become a selection")
        } catch { XCTAssertEqual(error as? TransferError, .clipboardUnavailable) }
        XCTAssertTrue(session.operands.isEmpty)
        XCTAssertEqual(io.restoreCount, 0)
        XCTAssertEqual(io.currentText, "987654")
    }

    @MainActor
    func testWriteBetweenReadingAndRestoringAbortsWithoutRestoring() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.copiedText = "80"
        io.onRead = { io.currentText = "new user clipboard"; io.clipboardRevision += 1 }
        do {
            try await SelectionTransfer(session: session).capture(using: io)
            XCTFail("Text read while the clipboard changed must not be trusted")
        } catch { XCTAssertEqual(error as? TransferError, .clipboardUnavailable) }
        XCTAssertTrue(session.operands.isEmpty)
        XCTAssertEqual(io.currentText, "new user clipboard")
        XCTAssertEqual(io.restoreCount, 0)
    }

    @MainActor
    func testFailedRestoreIsReportedWithTheAddedSelection() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.copiedText = "5"
        io.failsRestore = true
        let outcome = try await SelectionTransfer(session: session).capture(using: io)
        XCTAssertTrue(outcome.accepted)
        XCTAssertFalse(outcome.clipboardRestored)
        XCTAssertEqual(try session.result().value, 5)
        let exposed = FakeSelectionIO()
        exposed.exposedText = "7"
        let exposedOutcome = try await SelectionTransfer(session: session).capture(using: exposed)
        XCTAssertTrue(exposedOutcome.clipboardRestored)
    }

    @MainActor
    func testConcealedClipboardRefusesCopyFallback() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.snapshotTypes = [ClipboardSnapshot.concealedType]
        io.copiedText = "5"
        do {
            try await SelectionTransfer(session: session).capture(using: io)
            XCTFail("A concealed clipboard must not be copied and rewritten")
        } catch { XCTAssertEqual(error as? TransferError, .concealedClipboard) }
        XCTAssertEqual(io.copyCount, 0)
        XCTAssertEqual(io.restoreCount, 0)
        XCTAssertTrue(session.operands.isEmpty)
    }

    @MainActor
    func testConcealedClipboardStillAllowsAccessibilityText() async throws {
        let session = CalculatorSession()
        let io = FakeSelectionIO()
        io.snapshotTypes = [ClipboardSnapshot.concealedType]
        io.exposedText = "7"
        try await SelectionTransfer(session: session).capture(using: io)
        XCTAssertEqual(try session.result().value, 7)
        XCTAssertEqual(io.copyCount, 0)
    }
}

@MainActor
private final class FakeSelectionIO: SelectionTransferIO {
    var sourceName = "Streamlit"
    var sourceIsActive = true
    var clipboardRevision = 10
    var exposedText: String?
    var copiedText: String?
    var currentText = "previous clipboard"
    var copyCount = 0
    var restoreCount = 0
    var onWait: (() -> Void)?
    var onRead: (() -> Void)?
    var copyDelay = 0
    var copiesNonText = false
    var holdsNonText = false
    var snapshotTypes: [String] = []
    var onWaitNumber: ((Int) -> Void)?
    var failsRestore = false
    private var waitCount = 0

    func selectedText() async -> String? { exposedText }
    func snapshotClipboard() throws -> ClipboardSnapshot {
        var item = ["public.utf8-plain-text": Data(currentText.utf8)]
        for type in snapshotTypes { item[type] = Data() }
        return ClipboardSnapshot(items: [item], revision: clipboardRevision)
    }
    func copySelection() throws { copyCount += 1 }
    func clipboardText() -> String? {
        let value: String? = holdsNonText ? nil : currentText
        onRead?()
        return value
    }
    func restoreClipboard(_ snapshot: ClipboardSnapshot, replacing revision: Int) -> Bool {
        guard clipboardRevision == revision, !failsRestore else { return false }
        currentText = String(data: snapshot.items[0]["public.utf8-plain-text"]!, encoding: .utf8)!
        holdsNonText = false
        clipboardRevision += 1
        restoreCount += 1
        return true
    }
    func waitForCopy() async {
        waitCount += 1
        if waitCount > copyDelay, copiesNonText {
            holdsNonText = true
            clipboardRevision += 1
            copiesNonText = false
        }
        if waitCount > copyDelay, let copiedText {
            currentText = copiedText
            clipboardRevision += 1
            self.copiedText = nil
        }
        onWait?()
        onWaitNumber?(waitCount)
    }
}
