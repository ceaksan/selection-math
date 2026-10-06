import XCTest
@testable import MathCore

final class ResultDecimalsTests: XCTestCase {
    func testFixedDecimalsPadAndRoundHalfAwayFromZero() {
        XCTAssertEqual(NumberParser.format(5, style: .english, decimals: 2), "5.00")
        XCTAssertEqual(NumberParser.format(Decimal(string: "2.345")!, style: .english, decimals: 2), "2.35")
        XCTAssertEqual(NumberParser.format(Decimal(string: "-2.345")!, style: .english, decimals: 2), "-2.35")
        XCTAssertEqual(NumberParser.format(Decimal(string: "1234567.891")!, style: .turkish, decimals: 2), "1.234.567,89")
        XCTAssertEqual(NumberParser.format(Decimal(string: "18.6")!, style: .english, decimals: 0), "19")
        XCTAssertEqual(NumberParser.format(Decimal(string: "-0.001")!, style: .english, decimals: 2), "0.00")
    }

    func testAutomaticDecimalsKeepUpToEightDigits() {
        XCTAssertEqual(NumberParser.format(Decimal(string: "0.123456789")!, style: .english, decimals: nil), "0.12345679")
        XCTAssertEqual(NumberParser.format(5, style: .english, decimals: nil), "5")
    }

    func testOutOfRangeDecimalsAreClamped() {
        XCTAssertEqual(NumberParser.format(Decimal(string: "0.123456789")!, style: .english, decimals: 12), "0.12345679")
        XCTAssertEqual(NumberParser.format(Decimal(string: "1.5")!, style: .english, decimals: -3), "2")
    }

    func testResultTextAndCopyUseTheChosenDecimals() throws {
        let ratio = try Arithmetic.calculate(
            [Operand(value: 10, isPercent: false, source: ""), Operand(value: 5, isPercent: false, source: "")],
            operation: .ratio)
        XCTAssertEqual(ratio.text(style: .english, decimals: 2), "2.00")
        XCTAssertEqual(ratio.copyText(style: .english, decimals: 2), "2.00")
        let change = try Arithmetic.calculate(
            [Operand(value: 3, isPercent: false, source: ""), Operand(value: 4, isPercent: false, source: "")],
            operation: .change)
        XCTAssertEqual(change.text(style: .english, decimals: 2), "33.33%")
        let points = try Arithmetic.calculate(
            [Operand(value: Decimal(string: "0.105")!, isPercent: true, source: ""),
             Operand(value: Decimal(string: "0.05")!, isPercent: true, source: "")],
            operation: .difference)
        XCTAssertEqual(points.text(style: .english, decimals: 1), "5.5 pp")
        XCTAssertEqual(points.copyText(style: .english, decimals: 1), "5.5")
    }
}
