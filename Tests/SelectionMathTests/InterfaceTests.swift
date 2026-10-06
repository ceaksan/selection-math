import SwiftUI
import XCTest
@testable import SelectionMath

final class InterfaceTests: XCTestCase {
    func testAppOwnedTextResolvesInEnglish() {
        XCTAssertEqual(L("capture.selection"), "Add selection")
        XCTAssertEqual(L("capture.screen"), "Capture area")
        XCTAssertEqual(L("reset"), "Reset")
        XCTAssertEqual(L("appearance.dark"), "Dark")
        XCTAssertEqual(L("permission.grant"), "Allow access")
    }

    func testEveryOperationAndErrorHasAnEnglishLabel() {
        let keys = ["sum", "difference", "product", "quotient", "average", "ratio", "change"].map { "operation." + $0 }
            + ["noNumbers", "invalidNumber", "tooManyNumbers", "needsTwo", "zeroDivision", "overflow", "missingOperand"].map { "error." + $0 }
            + ["noSelection", "sourceChanged", "clipboardUnavailable", "concealedClipboard", "busy"].map { "transfer." + $0 }
            + ["needsModifier", "duplicate", "taken", "record", "recording", "resetDefaults", "title"].map { "shortcut." + $0 }
            + ShortcutAction.allCases.map { "shortcut.action." + $0.rawValue }
            + ["compact.enter", "compact.exit", "settings", "undoReset", "done", "about", "about.madeBy"]
            + ["status.addedSkipped", "status.addedNotRestored", "shortcut.invalidKey", "status.restored"]
            + About.links.map(\.key)
        for key in keys {
            XCTAssertNotEqual(L(key), key, "Missing resource: \(key)")
            XCTAssertFalse(L(key).isEmpty)
        }
    }

    func testOnboardingAdvancesToShortcutAndTerminates() {
        let welcome = OnboardingStep.welcome
        XCTAssertEqual(welcome.next, .access)
        XCTAssertEqual(welcome.next?.next, .shortcut)
        XCTAssertNil(welcome.next?.next?.next)
        for step in OnboardingStep.allCases {
            XCTAssertNotEqual(L(step.titleKey), step.titleKey)
            XCTAssertNotEqual(L(step.detailKey), step.detailKey)
        }
    }

    @MainActor
    func testStatusMessageClearsAfterItsLifetimeWithoutErasingNewerMessages() async throws {
        let model = AppModel()
        model.messageLifetime = 0.2
        model.inform("status.added")
        XCTAssertEqual(model.message, L("status.added"))
        try await Task.sleep(nanoseconds: 100_000_000)
        model.inform("status.copied")
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(model.message, L("status.copied"))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(model.message, "")
    }

    func testAboutLinksPointToTheAuthorsPublicProfiles() {
        XCTAssertEqual(About.author, "Ceyhun Aksan")
        XCTAssertEqual(About.links.map(\.url.absoluteString), [
            "https://ceaksan.com", "https://github.com/ceaksan", "https://x.com/ceaksan",
            "https://github.com/ceaksan/selection-math"
        ])
    }

    func testAppearanceOffersSystemLightAndDark() {
        XCTAssertNil(AppAppearance.system.nsAppearance)
        XCTAssertEqual(AppAppearance.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(AppAppearance.dark.nsAppearance?.name, .darkAqua)
        XCTAssertNil(AppAppearance.system.colorScheme)
        XCTAssertEqual(AppAppearance.light.colorScheme, .light)
        XCTAssertEqual(AppAppearance.dark.colorScheme, .dark)
    }

    func testVersionUsesBundleMetadata() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try PropertyListSerialization.data(fromPropertyList: [
            "CFBundleIdentifier": "test.selectionmath.version",
            "CFBundleShortVersionString": "9.8.7",
            "CFBundleVersion": "654"
        ], format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url: directory))
        XCTAssertEqual(AppVersion.label(bundle: bundle), "v9.8.7 (654)")
    }
}
