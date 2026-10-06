import AppKit
import ScreenCaptureKit
import Vision

enum CaptureError: String, Error {
    case permission = "permission.screen"
    case unavailable = "capture.unavailable"
    case tooSmall = "capture.tooSmall"
}

enum TextRecognition {
    static func read(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[VNRecognizedTextObservation]] = []
        for observation in observations {
            if let anchor = rows.last?.first,
               abs(anchor.boundingBox.midY - observation.boundingBox.midY) < min(anchor.boundingBox.height, observation.boundingBox.height) * 0.5 {
                rows[rows.count - 1].append(observation)
            } else { rows.append([observation]) }
        }
        return rows.flatMap { $0.sorted { $0.boundingBox.minX < $1.boundingBox.minX } }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

@MainActor
final class ScreenReader {
    private var overlay: NSWindow?
    private let loadContent: () async throws -> SCShareableContent

    init(
        loadContent: @escaping () async throws -> SCShareableContent = {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        }
    ) {
        self.loadContent = loadContent
    }

    nonisolated static func cropRect(selection: CGRect, screenSize: CGSize, imageSize: CGSize) -> CGRect {
        let scaleX = imageSize.width / screenSize.width
        let scaleY = imageSize.height / screenSize.height
        return CGRect(x: selection.minX * scaleX, y: (screenSize.height - selection.maxY) * scaleY,
                      width: selection.width * scaleX, height: selection.height * scaleY).integral
    }

    func capture() async throws -> String? {
        do {
            return try await captureRegion()
        } catch {
            let failure = error as NSError
            if failure.domain == SCStreamErrorDomain, failure.code == SCStreamError.Code.userDeclined.rawValue {
                throw CaptureError.permission
            }
            throw error
        }
    }

    private func captureRegion() async throws -> String? {
        let content = try await loadContent()
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw CaptureError.unavailable
        }
        guard let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else {
            throw CaptureError.unavailable
        }
        let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * screen.backingScaleFactor)
        config.height = Int(screen.frame.height * screen.backingScaleFactor)
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        guard let rectangle = await chooseRegion(image: image, screen: screen) else { return nil }
        let crop = Self.cropRect(selection: rectangle, screenSize: screen.frame.size,
                                 imageSize: CGSize(width: image.width, height: image.height))
        guard crop.width >= 6, crop.height >= 6, let cropped = image.cropping(to: crop) else { throw CaptureError.tooSmall }
        return try await Task.detached(priority: .userInitiated) { try TextRecognition.read(cropped) }.value
    }

    private func chooseRegion(image: CGImage, screen: NSScreen) async -> CGRect? {
        await withCheckedContinuation { continuation in
            let window = CaptureWindow(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
            window.isFloatingPanel = true
            window.hidesOnDeactivate = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            let view = RegionView(frame: CGRect(origin: .zero, size: screen.frame.size), image: image)
            var observer: NSObjectProtocol?
            view.completed = { [weak self] rect in
                if let observer { NotificationCenter.default.removeObserver(observer) }
                self?.overlay?.orderOut(nil)
                self?.overlay = nil
                continuation.resume(returning: rect)
            }
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window,
                                                              queue: .main) { [weak window, weak view] _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let window, let view, !window.isKeyWindow else { return }
                        let successor = NSApp.keyWindow
                        Log.capture.notice("Region overlay lost key status; successor: \(successor.map { String(describing: type(of: $0)) } ?? "none", privacy: .public)")
                        if successor == nil {
                            view.cancel()
                        } else {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }
            }
            window.contentView = view
            overlay = window
            window.makeKeyAndOrderFront(nil)
            Log.capture.notice("Region overlay shown; key: \(window.isKeyWindow, privacy: .public), active: \(NSApp.isActive, privacy: .public)")
            window.makeFirstResponder(view)
        }
    }
}

private final class CaptureWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class RegionView: NSView {
    let image: NSImage
    var completed: ((CGRect?) -> Void)?
    private var origin: NSPoint?
    private var rectangle: CGRect?
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(frame: CGRect, image: CGImage) {
        self.image = NSImage(cgImage: image, size: frame.size)
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        let shade = NSBezierPath(rect: bounds)
        if let rectangle { shade.appendRect(rectangle) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.25).setFill()
        shade.fill()
        if let rectangle {
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(rect: rectangle)
            border.lineWidth = 2
            border.stroke()
        }
        let text = L("capture.drag") as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let background = CGRect(x: (bounds.width - size.width) / 2 - 16, y: bounds.height - 85,
                                width: size.width + 32, height: 42)
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: background, xRadius: 12, yRadius: 12).fill()
        text.draw(at: CGPoint(x: background.minX + 16, y: background.minY + 12), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        origin = convert(event.locationInWindow, from: nil)
        rectangle = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin else { return }
        let end = convert(event.locationInWindow, from: nil)
        rectangle = CGRect(x: min(origin.x, end.x), y: min(origin.y, end.y),
                           width: abs(origin.x - end.x), height: abs(origin.y - end.y)).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        finish(rectangle)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { finish(nil) }
    }

    func cancel() { finish(nil) }

    private func finish(_ rectangle: CGRect?) {
        let callback = completed
        completed = nil
        callback?(rectangle)
    }
}
