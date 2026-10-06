import XCTest
@testable import MathCore

final class CalculatorTests: XCTestCase {
    func testTabAfterPlaceholderSignDoesNotNegateNextCell() throws {
        let values = try NumberParser.parse("-\t$ 1,234 | $ -\t5", style: .english)
        XCTAssertEqual(values.map(\.value), [1234, 5])
    }

    func testCommaBeforeSuffixSkipsTheWholeFragment() throws {
        let english = try NumberParser.scan("$1,250K | 40 | 1,2", style: .english)
        XCTAssertEqual(english.operands.map(\.value), [40, 1, 2])
        XCTAssertEqual(english.skipped, ["$1,250K"])
        let turkish = try NumberParser.scan("1,5K | 3", style: .turkish)
        XCTAssertEqual(turkish.operands.map(\.value), [3])
        XCTAssertEqual(turkish.skipped, ["1,5K"])
    }

    @MainActor
    func testSwapPairReversesTwoOperandsForPercentageChange() throws {
        let session = CalculatorSession()
        session.operation = .change
        try session.accept("150 | 100", source: "Table", generation: session.generation)
        XCTAssertTrue(session.canSwapPair)
        session.swapPair()
        XCTAssertEqual(session.operands.map(\.value), [100, 150])
        XCTAssertEqual(try session.result().value, Decimal(string: "0.5")!)
        try session.accept("1", source: "Table", generation: session.generation)
        XCTAssertFalse(session.canSwapPair)
        session.swapPair()
        XCTAssertEqual(session.operands.map(\.value), [100, 150, 1])
    }
    @MainActor
    func testGroupedTurkishExponentsKeepTheirMagnitude() throws {
        let session = CalculatorSession()
        session.style = .turkish
        try session.accept("1.234e3 | 1.234.567e2", source: "Table", generation: session.generation)
        XCTAssertEqual(session.operands.map(\.value), [1234000, 123456700])
    }

    @MainActor
    func testWhitespacePreservesNegativeSigns() throws {
        let session = CalculatorSession()
        try session.accept("( $1,234.56 ) | -  5", source: "Screen", generation: session.generation)
        XCTAssertEqual(session.operands.map(\.value), [Decimal(string: "-1234.56")!, -5])
    }

    @MainActor
    func testSkippedFragmentsBesideCommaSeparatedNumbersAreReported() throws {
        let session = CalculatorSession()
        let result = try session.accept("1.2K,40 Q3,10", source: "Table", generation: session.generation)
        XCTAssertEqual(session.operands.map(\.value), [40, 10])
        XCTAssertEqual(result.skipped, ["1.2K", "Q3"])
    }

    func testDotDecimalRemainsOneNumberInTurkishFormat() throws {
        let values = try NumberParser.parse("5.60", style: .turkish)
        XCTAssertEqual(values.map(\.value), [Decimal(string: "5.60")!])
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .sum).value, Decimal(string: "5.60"))
    }

    func testCurrencySignsAndExponentsKeepTheirValue() throws {
        let english = try NumberParser.parse("-$1,234.56 $-5 ($7) € 3 1e3 2.5E-2", style: .english)
        XCTAssertEqual(english.map(\.value), [Decimal(string: "-1234.56")!, -5, -7, 3, 1000, Decimal(string: "0.025")!])
        XCTAssertEqual(try NumberParser.parse("-₺1.234,5", style: .turkish).map(\.value), [Decimal(string: "-1234.5")!])
    }

    @MainActor
    func testUnreadableNumberLikeTokensAreReportedAsSkipped() async throws {
        let session = CalculatorSession()
        let acceptance = try session.accept("Q3 revenue 1.2K | 310,872 #1e3a8a", source: "Browser", generation: session.generation)
        XCTAssertTrue(acceptance.accepted)
        XCTAssertEqual(acceptance.skipped, ["Q3", "1.2K", "#1e3a8a"])
        XCTAssertEqual(session.operands.map(\.value), [310872])
        XCTAssertEqual(try session.accept("12 40", source: "Browser", generation: session.generation).skipped, [])
    }

    @MainActor
    func testEditKeepsTheFormatItStartedWith() async throws {
        let session = CalculatorSession()
        try session.accept("1", source: "Browser", generation: session.generation)
        session.style = .turkish
        try session.edit(session.operands[0].id, text: "1.234", style: .english)
        XCTAssertEqual(session.operands[0].value, Decimal(string: "1.234"))
        try session.edit(session.operands[0].id, text: "1.234")
        XCTAssertEqual(session.operands[0].value, 1234)
    }

    func testExpressionFoldsNegativeSignsIntoTheOperator() throws {
        let values = try NumberParser.parse("310,872 413,435 -102,563", style: .english)
        XCTAssertEqual(Arithmetic.expression(values, operation: .sum, style: .english), "310,872 + 413,435 − 102,563")
        XCTAssertEqual(Arithmetic.expression(values, operation: .difference, style: .english), "310,872 − 413,435 + 102,563")
        let leading = try NumberParser.parse("-5 -2 3%", style: .english)
        XCTAssertEqual(Arithmetic.expression(leading, operation: .sum, style: .english), "−5 − 2 + 3%")
        XCTAssertEqual(Arithmetic.expression(leading, operation: .product, style: .english), "−5 × (−2) × 3%")
        XCTAssertEqual(Arithmetic.expression(leading, operation: .quotient, style: .turkish), "−5 ÷ (−2) ÷ 3%")
    }

    func testParenthesizedNumbersAreNegative() throws {
        let english = try NumberParser.parse("(1,234) (3.5%) 12 (7", style: .english)
        XCTAssertEqual(english.map(\.value), [-1234, Decimal(string: "-0.035")!, 12, 7])
        XCTAssertTrue(english[1].isPercent)
        XCTAssertEqual(try NumberParser.parse("(1.234,5)", style: .turkish).map(\.value), [Decimal(string: "-1234.5")!])
        XCTAssertEqual(try NumberParser.single("(500)", style: .english).value, -500)
    }

    func testLargeDecimalKeepsAllDigitsWhenFormatted() throws {
        let value = try XCTUnwrap(Decimal(string: "12345678901234567.89"))
        XCTAssertEqual(NumberParser.format(value, style: .english), "12,345,678,901,234,567.89")
        XCTAssertEqual(NumberParser.format(value, style: .turkish), "12.345.678.901.234.567,89")
    }

    func testScreenshotFormatsAndSeparators() throws {
        let values = try NumberParser.parse("310,872 | 79,013\n-102563\t3.71% 0.912", style: .english)
        XCTAssertEqual(values.map(\.value), [310872, 79013, -102563, Decimal(string: "0.0371")!, Decimal(string: "0.912")!])
        XCTAssertTrue(values[3].isPercent)
        XCTAssertEqual(try NumberParser.parse("120,80", style: .english).map(\.value), [120, 80])
        XCTAssertEqual(try NumberParser.parse("120 80\n40 | 20", style: .english).map(\.value), [120, 80, 40, 20])
    }

    func testTurkishFormatsUnicodeMinusAndPercent() throws {
        let values = try NumberParser.parse("310.872 | −1.234,5\n3,71%", style: .turkish)
        XCTAssertEqual(values.map(\.value), [310872, Decimal(string: "-1234.5")!, Decimal(string: "0.0371")!])
        XCTAssertEqual(values[1].text(style: .turkish), "-1.234,5")
    }

    func testDecimalArithmeticAndOperationOrder() throws {
        let decimal = try NumberParser.parse("0.1 0.2", style: .english)
        XCTAssertEqual(try Arithmetic.calculate(decimal, operation: .sum).value, Decimal(string: "0.3"))
        let values = try NumberParser.parse("120 80 2", style: .english)
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .difference).value, 38)
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .product).value, 19200)
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .quotient).value, Decimal(string: "0.75"))
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .average).value, Decimal(202) / 3)
    }

    func testRatiosAndPercentageChangeHaveExplicitDirection() throws {
        let values = try NumberParser.parse("80 120", style: .english)
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .change).text(style: .english), "50%")
        XCTAssertEqual(try Arithmetic.calculate(Array(values.reversed()), operation: .ratio).value, Decimal(string: "1.5"))
        XCTAssertThrowsError(try Arithmetic.calculate([values[0]], operation: .ratio))
    }

    func testPercentageArithmetic() throws {
        let values = try NumberParser.parse("3.71% 4.2%", style: .english)
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .sum).text(style: .english), "7.91%")
        let difference = try Arithmetic.calculate(values, operation: .difference)
        XCTAssertEqual(difference.text(style: .english), "-0.49 pp")
        XCTAssertEqual(difference.copyText(style: .english), "-0.49")
        XCTAssertTrue(difference.isPercentagePoints)
        XCTAssertEqual(try Arithmetic.calculate(values, operation: .sum).copyText(style: .english), "7.91%")
        let mixed = try NumberParser.parse("100 10%", style: .english)
        XCTAssertEqual(try Arithmetic.calculate(mixed, operation: .sum).value, Decimal(string: "100.1"))
    }

    func testZeroDivisorsAndOverflowAreErrors() throws {
        let zero = try NumberParser.parse("12 0", style: .english)
        XCTAssertThrowsError(try Arithmetic.calculate(zero, operation: .quotient)) {
            XCTAssertEqual($0 as? MathError, .zeroDivision)
        }
        let values = [Operand(value: Decimal.greatestFiniteMagnitude), Operand(value: 10)]
        XCTAssertThrowsError(try Arithmetic.calculate(values, operation: .product))
        XCTAssertThrowsError(try Arithmetic.calculate(Array(zero.reversed()), operation: .change))
    }

    @MainActor
    func testSeparateCapturesEditRemoveAndReorderThroughSession() async throws {
        let session = CalculatorSession()
        try session.accept("310,872", source: "Browser", generation: session.generation)
        try session.accept("79,013", source: "Browser", generation: session.generation)
        XCTAssertEqual(try session.result().value, 389885)
        let firstID = session.operands[0].id
        try session.edit(firstID, text: "100")
        XCTAssertEqual(try session.result().value, 79113)
        session.operation = .difference
        session.move(firstID, by: 1)
        XCTAssertEqual(try session.result().value, 78913)
        session.remove(firstID)
        XCTAssertEqual(try session.result().value, 79013)
    }

    @MainActor
    func testInvalidEditAndCaptureDoNotMutateOperands() async throws {
        let session = CalculatorSession()
        try session.accept("12", source: "Browser", generation: session.generation)
        let before = session.operands
        XCTAssertThrowsError(try session.edit(before[0].id, text: "12 | 40"))
        XCTAssertThrowsError(try session.edit(before[0].id, text: "not a number"))
        XCTAssertThrowsError(try session.accept("hello", source: "Browser", generation: session.generation))
        XCTAssertEqual(session.operands, before)
    }

    @MainActor
    func testResetClearsStateAndRejectsInFlightCapture() async throws {
        let session = CalculatorSession()
        let oldGeneration = session.generation
        try session.accept("12 40", source: "Screen", generation: oldGeneration)
        session.operation = .product
        session.reset()
        XCTAssertFalse(try session.accept("999", source: "Screen", generation: oldGeneration).accepted)
        XCTAssertTrue(session.operands.isEmpty)
        XCTAssertEqual(session.operation, .sum)
        try session.accept("7", source: "Browser", generation: session.generation)
        XCTAssertEqual(try session.result().value, 7)
        session.undoCapture()
        XCTAssertTrue(session.operands.isEmpty)
        session.undoCapture()
        XCTAssertTrue(session.operands.isEmpty)
    }

    @MainActor
    func testUndoResetRestoresOperandsOperationAndUndoHistory() async throws {
        let session = CalculatorSession()
        try session.accept("10", source: "Browser", generation: session.generation)
        try session.accept("20 30", source: "Browser", generation: session.generation)
        session.operation = .product
        let before = session.operands
        let staleGeneration = session.generation
        session.reset()
        XCTAssertTrue(session.canUndoReset)
        session.undoReset()
        XCTAssertEqual(session.operands, before)
        XCTAssertEqual(session.operation, .product)
        XCTAssertFalse(session.canUndoReset)
        XCTAssertFalse(try session.accept("999", source: "Screen", generation: staleGeneration).accepted)
        session.undoCapture()
        XCTAssertEqual(session.operands.map(\.value), [10])
    }

    @MainActor
    func testUndoResetExpiresAfterTheNextChange() async throws {
        let session = CalculatorSession()
        try session.accept("10", source: "Browser", generation: session.generation)
        session.reset()
        try session.accept("5", source: "Browser", generation: session.generation)
        XCTAssertFalse(session.canUndoReset)
        session.undoReset()
        XCTAssertEqual(session.operands.map(\.value), [5])
        session.reset()
        session.reset()
        XCTAssertTrue(session.canUndoReset)
        session.undoReset()
        XCTAssertEqual(session.operands.map(\.value), [5])
    }

    @MainActor
    func testEqualValuesAreIndependentOperandsAndUndoRemovesOneCapture() async throws {
        let session = CalculatorSession()
        try session.accept("10", source: "Browser", generation: session.generation)
        try session.accept("10 20", source: "Browser", generation: session.generation)
        XCTAssertEqual(Set(session.operands.map(\.id)).count, 3)
        session.undoCapture()
        XCTAssertEqual(session.operands.map(\.value), [10])
    }

    @MainActor
    func testCaptureLimitIsAtomicAndFormatChangePreservesStoredValues() async throws {
        let session = CalculatorSession()
        try session.accept("310,872", source: "Browser", generation: session.generation)
        session.style = .turkish
        XCTAssertEqual(try session.result().value, 310872)
        XCTAssertThrowsError(try session.accept(Array(repeating: "1", count: 100).joined(separator: " "),
                                               source: "Browser", generation: session.generation))
        XCTAssertEqual(session.operands.count, 1)
    }
}
