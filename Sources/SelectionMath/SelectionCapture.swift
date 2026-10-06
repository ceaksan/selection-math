import AppKit
import ApplicationServices
import MathCore
import os

enum Log {
    static let capture = Logger(subsystem: "com.ceaksan.selectionmath", category: "capture")
    static let shortcuts = Logger(subsystem: "com.ceaksan.selectionmath", category: "shortcuts")
}

struct SelectionSnapshot: Sendable {
    let text: String
}

enum SelectionReader {
    static func read(pid: pid_t) -> SelectionSnapshot? {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.3)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(element, 0.3)
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &role)
        guard (role as? String) != "AXSecureTextField" else { return nil }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return SelectionSnapshot(text: text)
    }
}

@MainActor
final class AppModel: ObservableObject {
    let session = CalculatorSession()
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var capturing = false
    @Published var screenText = ""
    @Published var reviewScreenCapture = false
    @Published var showingSettings = false
    @Published private(set) var message = ""
    @Published private(set) var isError = false
    @Published private(set) var shortcuts: [ShortcutAction: Shortcut]
    @Published var compact: Bool {
        didSet {
            defaults.set(compact, forKey: "compactMode")
            applyCompact(compact)
        }
    }
    var showPanel: () -> Void = {}
    var focusPanel: () -> Void = {}
    var applyCompact: (Bool) -> Void = { _ in }
    var messageLifetime: TimeInterval = 4
    private var messageToken = 0
    private var permissionTimer: Timer?
    private var screenGeneration: UInt = 0
    private let defaults: UserDefaults
    private let screenReader = ScreenReader()
    private let hotkeys = GlobalHotkeys()
    private lazy var transfer = SelectionTransfer(session: session)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcuts = ShortcutStore.load(from: defaults)
        compact = defaults.bool(forKey: "compactMode")
    }

    func start() {
        hotkeys.action = { [weak self] action in
            switch action {
            case .addSelection: self?.captureSelection()
            case .captureArea: self?.captureScreen()
            case .showPanel: self?.showPanel()
            }
        }
        registerShortcuts()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let granted = AXIsProcessTrusted()
                if granted != self.accessibilityGranted { self.accessibilityGranted = granted }
            }
        }
        permissionTimer?.tolerance = 1
    }

    func stop() {
        permissionTimer?.invalidate()
        hotkeys.stop()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        if !accessibilityGranted { inform("permission.accessibility") }
    }

    func shortcutSymbols(_ action: ShortcutAction) -> String {
        shortcuts[action]?.symbols(layout: KeyboardLayout.current()) ?? ""
    }

    func shortcutParts(_ action: ShortcutAction) -> [String] {
        shortcuts[action]?.parts(layout: KeyboardLayout.current()) ?? []
    }

    func shortcutSpoken(_ action: ShortcutAction) -> String {
        shortcuts[action]?.spoken(layout: KeyboardLayout.current()) ?? ""
    }

    func suspendShortcuts() { hotkeys.unregisterAll() }

    func resumeShortcuts() { registerShortcuts() }

    func setShortcut(_ shortcut: Shortcut, for action: ShortcutAction) -> String? {
        if let issue = ShortcutStore.validate(shortcut, for: action, in: shortcuts) {
            registerShortcuts()
            switch issue {
            case .needsModifier: return L("shortcut.needsModifier")
            case .invalidKey: return L("shortcut.invalidKey")
            case .duplicate(let other): return String(format: L("shortcut.duplicate"), L(other.titleKey))
            }
        }
        var updated = shortcuts
        updated[action] = shortcut
        if hotkeys.register(updated).contains(action) {
            Log.shortcuts.error("Registration failed for \(action.rawValue, privacy: .public)")
            registerShortcuts()
            return String(format: L("shortcut.taken"), shortcut.symbols(layout: KeyboardLayout.current()))
        }
        shortcuts = updated
        ShortcutStore.save(updated, to: defaults)
        return nil
    }

    func resetShortcuts() {
        shortcuts = Shortcut.defaults
        ShortcutStore.save(shortcuts, to: defaults)
        registerShortcuts()
    }

    func captureSelection() {
        guard !capturing, !reviewScreenCapture else { return }
        guard AXIsProcessTrusted() else { requestAccessibility(); return }
        guard let source = NSWorkspace.shared.frontmostApplication,
              source.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            inform("capture.selectFirst", arguments: [shortcutSpoken(.addSelection)], error: true)
            return
        }
        capturing = true
        Task {
            defer { capturing = false }
            do {
                let outcome = try await transfer.capture(using: MacSelectionIO(application: source))
                if outcome.accepted {
                    reportAdded(skipped: outcome.skipped, clipboardRestored: outcome.clipboardRestored)
                    showPanel()
                }
            } catch let error as TransferError {
                Log.capture.error("Selection transfer failed: \(error.rawValue, privacy: .public)")
                inform("transfer." + error.rawValue, error: true)
            } catch let error as MathError {
                Log.capture.notice("Selection rejected: \(error.rawValue, privacy: .public)")
                inform("error." + error.rawValue, error: true)
            } catch {
                let failure = error as NSError
                Log.capture.error("Selection transfer failed: \(failure.domain, privacy: .public) \(failure.code, privacy: .public)")
                inform("capture.useScreen", error: true)
            }
        }
    }

    func captureScreen() {
        guard !capturing, !reviewScreenCapture else { return }
        capturing = true
        let generation = session.generation
        let previousApp = NSWorkspace.shared.frontmostApplication
        Task {
            defer {
                capturing = false
                previousApp?.activate(options: [])
                if reviewScreenCapture { focusPanel() } else { showPanel() }
            }
            do {
                guard let text = try await screenReader.capture() else { inform("capture.cancelled"); return }
                guard generation == session.generation else { return }
                screenText = text
                screenGeneration = generation
                reviewScreenCapture = true
            } catch let error as CaptureError {
                Log.capture.error("Screen capture failed: \(error.rawValue, privacy: .public)")
                inform(error.rawValue, error: true)
            } catch {
                let failure = error as NSError
                Log.capture.error("Screen capture failed: \(failure.domain, privacy: .public) \(failure.code, privacy: .public)")
                show(L("capture.failed") + " " + error.localizedDescription, error: true)
            }
        }
    }

    func confirmScreenCapture() {
        if accept(screenText, source: L("source.screen"), generation: screenGeneration) {
            reviewScreenCapture = false
            screenText = ""
        }
    }

    @discardableResult
    func accept(_ text: String, source: String, generation: UInt) -> Bool {
        do {
            let acceptance = try session.accept(text, source: source, generation: generation)
            if acceptance.accepted {
                reportAdded(skipped: acceptance.skipped, clipboardRestored: true)
                showPanel()
            }
            return acceptance.accepted
        } catch let error as MathError {
            inform("error." + error.rawValue, error: true)
        } catch { inform("error.invalidNumber", error: true) }
        return false
    }

    func reset() {
        session.reset()
        reviewScreenCapture = false
        screenText = ""
        inform("status.reset")
    }

    func undoReset() {
        guard session.canUndoReset else { return }
        session.undoReset()
        inform("status.restored")
    }

    func copyResult() {
        guard !capturing else { return }
        guard let result = try? session.result() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.copyText(style: session.style), forType: .string)
        inform("status.copied")
    }

    func inform(_ key: String, arguments: [CVarArg] = [], error: Bool = false) {
        show(arguments.isEmpty ? L(key) : String(format: L(key), arguments: arguments), error: error)
    }

    private func reportAdded(skipped: [String], clipboardRestored: Bool) {
        if !clipboardRestored {
            inform("status.addedNotRestored", error: true)
        } else if !skipped.isEmpty {
            let shown = skipped.prefix(3).joined(separator: ", ") + (skipped.count > 3 ? ", ..." : "")
            inform("status.addedSkipped", arguments: [shown])
        } else {
            inform("status.added")
        }
    }

    private func show(_ text: String, error: Bool) {
        message = text
        isError = error
        messageToken &+= 1
        let token = messageToken
        let lifetime = error ? messageLifetime * 2 : messageLifetime
        announce(text)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard let self, self.messageToken == token else { return }
            self.message = ""
            self.isError = false
        }
    }

    private func announce(_ text: String) {
        guard let application = NSApp else { return }
        NSAccessibility.post(element: application, notification: .announcementRequested, userInfo: [
            .announcement: text,
            .priority: NSAccessibilityPriorityLevel.high.rawValue
        ])
    }

    private func registerShortcuts() {
        let failed = hotkeys.register(shortcuts)
        guard !failed.isEmpty else { return }
        Log.shortcuts.error("Registration failed for \(failed.map(\.rawValue).joined(separator: ","), privacy: .public)")
        inform("shortcut.unavailable", error: true)
    }
}
