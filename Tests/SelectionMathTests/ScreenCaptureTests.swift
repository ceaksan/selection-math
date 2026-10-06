import AppKit
import MathCore
import ScreenCaptureKit
import XCTest
@testable import SelectionMath

final class ScreenCaptureTests: XCTestCase {
    @MainActor
    func testCaptureReachesScreenCaptureKitAndPreservesOtherErrors() async {
        var requestedContent = false
        let reader = ScreenReader(loadContent: {
            requestedContent = true
            throw NSError(domain: "ScreenCaptureProbe", code: 42)
        })
        do {
            _ = try await reader.capture()
            XCTFail("The framework probe should return its original error")
        } catch {
            XCTAssertEqual((error as NSError).domain, "ScreenCaptureProbe")
            XCTAssertEqual((error as NSError).code, 42)
        }
        XCTAssertTrue(requestedContent)
    }

    @MainActor
    func testActualScreenCaptureDenialShowsPermissionError() async {
        let reader = ScreenReader(loadContent: {
            throw NSError(domain: SCStreamErrorDomain, code: SCStreamError.Code.userDeclined.rawValue)
        })
        do {
            _ = try await reader.capture()
            XCTFail("Denied capture must not continue")
        } catch {
            XCTAssertEqual(error as? CaptureError, .permission)
        }
    }

    @MainActor
    func testSameErrorCodeFromAnotherDomainIsNotPermissionDenial() async {
        let reader = ScreenReader(loadContent: {
            throw NSError(domain: "OtherFramework", code: SCStreamError.Code.userDeclined.rawValue)
        })
        do {
            _ = try await reader.capture()
            XCTFail("The original error should propagate")
        } catch {
            XCTAssertEqual((error as NSError).domain, "OtherFramework")
            XCTAssertNil(error as? CaptureError)
        }
    }
}

final class ScreenCapturePipelineTests: XCTestCase {
    func testSelectionMapsToImagePixelsOnARetinaScreen() {
        let crop = ScreenReader.cropRect(selection: CGRect(x: 100, y: 200, width: 300, height: 50),
                                         screenSize: CGSize(width: 1440, height: 900),
                                         imageSize: CGSize(width: 2880, height: 1800))
        XCTAssertEqual(crop, CGRect(x: 200, y: 1300, width: 600, height: 100))
    }

    func testTextRecognitionReadsRenderedNumbers() throws {
        let size = NSSize(width: 900, height: 160)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            ("310,872    79,013" as NSString).draw(at: NSPoint(x: 40, y: 50), withAttributes: [
                .font: NSFont.systemFont(ofSize: 56, weight: .medium), .foregroundColor: NSColor.black
            ])
            return true
        }
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let text = try TextRecognition.read(cgImage)
        XCTAssertEqual(try NumberParser.parse(text, style: .english).map(\.value), [310872, 79013])
    }
}
