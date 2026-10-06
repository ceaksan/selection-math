import XCTest
@testable import SelectionMath

final class ResultDecimalsSettingTests: XCTestCase {
    @MainActor
    func testDefaultsToAutomaticAndPersistsFixedAndClampedValues() throws {
        let suite = "selectionmath.decimals.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        XCTAssertNil(model.resultDecimals)

        model.resultDecimals = 2
        XCTAssertEqual(AppModel(defaults: defaults).resultDecimals, 2)
        model.resultDecimals = nil
        XCTAssertNil(AppModel(defaults: defaults).resultDecimals)

        model.resultDecimals = 12
        XCTAssertEqual(model.resultDecimals, 8)
        XCTAssertEqual(AppModel(defaults: defaults).resultDecimals, 8)

        defaults.set(-40, forKey: "resultDecimals")
        XCTAssertNil(AppModel(defaults: defaults).resultDecimals)
        defaults.set(99, forKey: "resultDecimals")
        XCTAssertEqual(AppModel(defaults: defaults).resultDecimals, 8)
    }
}
