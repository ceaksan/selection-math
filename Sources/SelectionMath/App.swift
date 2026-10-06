import AppKit
import MathCore
import SwiftUI

private let englishResources: Bundle = {
    let resources: Bundle
    if let url = Bundle.main.resourceURL?.appendingPathComponent("SelectionMath_SelectionMath.bundle"),
       let packaged = Bundle(url: url) {
        resources = packaged
    } else {
        resources = Bundle.module
    }
    return resources.url(forResource: "en", withExtension: "lproj").flatMap(Bundle.init(url:)) ?? resources
}()

func L(_ key: String) -> String {
    englishResources.localizedString(forKey: key, value: nil, table: nil)
}

@main
struct SelectionMathApplication {
    @MainActor
    static func main() {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--ocr-check" {
            do {
                let url = URL(fileURLWithPath: CommandLine.arguments[2])
                guard let image = NSImage(contentsOf: url),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw CaptureError.unavailable
                }
                let text = try TextRecognition.read(cgImage)
                print(text)
                let numbers = try NumberParser.parse(text, style: .english)
                print("Recognized operands: \(numbers.count)")
                return
            } catch {
                fputs("OCR check failed: \(error)\n", stderr)
                exit(1)
            }
        }
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            DistributedNotificationCenter.default().postNotificationName(AppDelegate.showNotification, object: nil,
                                                                         userInfo: nil, deliverImmediately: true)
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let showNotification = Notification.Name("com.ceaksan.selectionmath.show")
    private static let fullMinimum = NSSize(width: 400, height: 680)
    private static let fullDefault = NSSize(width: 420, height: 740)
    private static let compactMinimum = NSSize(width: 280, height: 250)
    private static let compactDefault = NSSize(width: 320, height: 300)
    private let model = AppModel()
    private var panel: CalculatorPanel!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = CalculatorPanel(contentRect: NSRect(origin: .zero, size: Self.fullDefault),
                                styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        panel.title = "Selection Math"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = Design.windowColor
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = Self.fullMinimum
        panel.setFrameAutosaveName("SelectionMathPanelV3")
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: PanelView(model: model, session: model.session))
        if !panel.setFrameUsingName("SelectionMathPanelV3") {
            if let frame = NSScreen.main?.visibleFrame {
                panel.setFrameTopLeftPoint(NSPoint(x: frame.maxX - 450, y: frame.maxY - 36))
            }
        }
        model.showPanel = { [weak self] in self?.panel.orderFrontRegardless() }
        model.focusPanel = { [weak self] in self?.panel.makeKeyAndOrderFront(nil) }
        model.applyCompact = { [weak self] compact in self?.resize(compact: compact, animate: true) }
        resize(compact: model.compact, animate: false)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showPanel),
                                                            name: Self.showNotification, object: nil)
        setupMenu()
        model.start()
        panel.orderFrontRegardless()
    }

    private func resize(compact: Bool, animate: Bool) {
        let minimum = compact ? Self.compactMinimum : Self.fullMinimum
        panel.minSize = minimum
        var frame = panel.frame
        let top = frame.maxY
        if compact {
            frame.size = Self.compactDefault
        } else if frame.width < minimum.width || frame.height < minimum.height {
            frame.size = Self.fullDefault
        }
        frame.origin.y = top - frame.height
        panel.setFrame(panel.constrainFrameRect(frame, to: panel.screen), display: true, animate: animate)
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sum", accessibilityDescription: "Selection Math")
        let menu = NSMenu()
        for (title, action) in [(L("menu.show"), #selector(showPanel)), (L("capture.screen"), #selector(captureScreen)),
                                (L("menu.settings"), #selector(showSettings))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = menu.copy() as? NSMenu
        mainMenu.addItem(appItem)
        let editItem = NSMenuItem(title: L("edit"), action: nil, keyEquivalent: "")
        let edit = NSMenu(title: L("edit"))
        edit.addItem(withTitle: L("undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L("redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func showPanel() { panel.makeKeyAndOrderFront(nil) }
    @objc private func captureScreen() { model.captureScreen() }

    @objc private func showSettings() {
        panel.makeKeyAndOrderFront(nil)
        model.showingSettings = true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}

final class CalculatorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
