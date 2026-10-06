import MathCore
import XCTest
@testable import SelectionMath

final class ManualEntryTests: XCTestCase {
    func testResultIsAppendedAfterExistingEntries() {
        XCTAssertEqual(ManualEntry.appending("-18.613", to: ""), "-18.613")
        XCTAssertEqual(ManualEntry.appending("-18.613", to: "  "), "-18.613")
        XCTAssertEqual(ManualEntry.appending("-18.613", to: "120 | 80"), "120 | 80 | -18.613")
        XCTAssertEqual(ManualEntry.appending("-18.613", to: "120 | 80 | "), "120 | 80 | -18.613")
    }

    @MainActor
    func testInsertedResultParsesBackToTheSameValue() throws {
        for style in NumberStyle.allCases {
            let session = CalculatorSession()
            session.style = style
            session.operation = .average
            try session.accept("-1234567 | -18.5 | 10% | 0.5", source: "Table", generation: session.generation)
            let result = try session.result()
            let text = ManualEntry.appending(result.copyText(style: style), to: "")
            let parsed = try NumberParser.single(text, style: style)
            XCTAssertEqual(parsed.value, result.value, "\(style)")
        }
    }
}
