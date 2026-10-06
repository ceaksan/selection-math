import AppKit
import XCTest
@testable import SelectionMath

final class PanelFocusTests: XCTestCase {
    private final class FocusableView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    @MainActor
    private func makePanel() -> CalculatorPanel {
        CalculatorPanel(contentRect: NSRect(x: 0, y: 0, width: 240, height: 120),
                        styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
    }

    @MainActor
    func testBecomingKeyClearsAutomaticControlFocus() throws {
        let panel = makePanel()
        let control = FocusableView(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
        panel.contentView?.addSubview(control)
        XCTAssertTrue(panel.makeFirstResponder(control))
        panel.becomeKey()
        XCTAssertTrue(panel.firstResponder === panel)
    }

    @MainActor
    func testBecomingKeyKeepsAnActiveTextEdit() throws {
        let panel = makePanel()
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 22))
        panel.contentView?.addSubview(field)
        XCTAssertTrue(panel.makeFirstResponder(field))
        let editor = try XCTUnwrap(panel.firstResponder as? NSText)
        panel.becomeKey()
        XCTAssertTrue(panel.firstResponder === editor)
    }
}
