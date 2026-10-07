import AppKit
import Carbon
import MathCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @State private var recording: ShortcutAction?
    @State private var error: String?
    @State private var lastFixedDecimals = ResultDecimals.fixedDefault
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("settings")).font(.system(size: 18, weight: .semibold))
                .padding([.horizontal, .top], 24).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    shortcuts
                    section(L("appearance")) {
                        SoftSegmented(options: AppAppearance.allCases.map { ($0, L("appearance." + $0.rawValue)) },
                                      selection: $appearance)
                    }
                    decimals
                    about
                }
                .padding(.horizontal, 24).padding(.bottom, 8)
            }
            HStack {
                Spacer()
                Button(L("done")) {
                    stopRecording()
                    model.showingSettings = false
                }.buttonStyle(SoftButtonStyle(kind: .primary)).keyboardShortcut(.defaultAction)
            }
            .padding(24)
        }
        .frame(width: 380).frame(maxHeight: 620).fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Design.text).background(Design.canvas)
        .focusEffectDisabled()
        .onDisappear { stopRecording() }
        .onAppear { if let value = model.resultDecimals { lastFixedDecimals = value } }
    }

    private var decimals: some View {
        section(L("decimals")) {
            SoftSegmented(options: [(false, L("decimals.auto")), (true, L("decimals.fixed"))], selection: fixedDecimals)
                .accessibilityLabel(L("decimals"))
            if let value = model.resultDecimals {
                HStack(spacing: 8) {
                    Text(L("decimals.places")).font(.system(size: 13))
                    Spacer()
                    Button { setFixedDecimals(value - 1) } label: { Image(systemName: "minus") }
                        .buttonStyle(SoftButtonStyle(compact: true)).disabled(value == 0)
                        .accessibilityLabel(L("decimals.fewer"))
                    Text("\(value)").font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
                        .frame(minWidth: 18).accessibilityLabel(L("decimals.places") + " \(value)")
                    Button { setFixedDecimals(value + 1) } label: { Image(systemName: "plus") }
                        .buttonStyle(SoftButtonStyle(compact: true)).disabled(value == NumberParser.maximumDecimals)
                        .accessibilityLabel(L("decimals.more"))
                }
            }
            Text(L(model.resultDecimals == nil ? "decimals.hint.auto" : "decimals.hint.fixed"))
                .font(.system(size: 12)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fixedDecimals: Binding<Bool> {
        Binding(get: { model.resultDecimals != nil },
                set: { model.resultDecimals = $0 ? lastFixedDecimals : nil })
    }

    private func setFixedDecimals(_ value: Int) {
        model.resultDecimals = value
        lastFixedDecimals = model.resultDecimals ?? ResultDecimals.fixedDefault
    }

    private var shortcuts: some View {
        section(L("shortcut.title")) {
            Text(L("shortcut.hint")).font(.system(size: 12)).foregroundStyle(Design.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                ForEach(ShortcutAction.allCases) { action in
                    HStack {
                        Text(L(action.titleKey)).font(.system(size: 13))
                        Spacer()
                        Button { toggleRecording(action) } label: {
                            Text(recording == action ? L("shortcut.recording") : model.shortcutSymbols(action))
                                .font(.system(size: 13, weight: .medium, design: .rounded)).frame(minWidth: 96)
                        }
                        .buttonStyle(SoftButtonStyle(kind: recording == action ? .primary : .secondary, compact: true))
                        .help(L("shortcut.record"))
                        .accessibilityLabel(L(action.titleKey))
                        .accessibilityValue(recording == action ? L("shortcut.recording") : model.shortcutSpoken(action))
                        .accessibilityIdentifier("shortcut-\(action.rawValue)")
                    }
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(Design.danger).fixedSize(horizontal: false, vertical: true)
            }
            Button(L("shortcut.resetDefaults")) {
                stopRecording()
                error = model.resetShortcuts()
            }.buttonStyle(SoftButtonStyle(compact: true))
        }
    }

    private var about: some View {
        section(L("about")) {
            HStack(spacing: 12) {
                Image(systemName: "sum").font(.system(size: 20, weight: .semibold)).foregroundStyle(Design.accent)
                    .frame(width: 40, height: 40).background(Design.raised, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("title")).font(.system(size: 13, weight: .semibold))
                    Text(AppVersion.label).font(.system(size: 12)).foregroundStyle(Design.muted)
                        .accessibilityIdentifier("app-version")
                }
                Spacer()
            }
            Text(String(format: L("about.madeBy"), About.author)).font(.system(size: 12)).foregroundStyle(Design.muted)
            VStack(spacing: 2) {
                ForEach(About.links, id: \.key) { link in
                    Link(destination: link.url) {
                        HStack(spacing: 10) {
                            Image(systemName: link.symbol).font(.system(size: 12)).foregroundStyle(Design.muted).frame(width: 18)
                            Text(L(link.key)).font(.system(size: 13))
                            Spacer()
                            Text(link.label).font(.system(size: 12)).foregroundStyle(Design.muted)
                            Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(Design.muted)
                        }
                        .padding(.horizontal, 12).frame(height: 34).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L(link.key) + ", " + link.label)
                }
            }
            .padding(.vertical, 4)
            .background(Design.surface, in: RoundedRectangle(cornerRadius: 12))
            Link(destination: About.coffee) {
                Label(L("about.coffee"), systemImage: "cup.and.saucer").frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle())
            .accessibilityIdentifier("buy-me-a-coffee")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Design.muted)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func toggleRecording(_ action: ShortcutAction) {
        let wasRecording = recording == action
        stopRecording()
        guard !wasRecording else { return }
        error = nil
        recording = action
        model.suspendShortcuts()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let target = recording else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
            removeMonitor()
            recording = nil
            if event.keyCode == UInt16(kVK_Escape), flags.isEmpty {
                model.resumeShortcuts()
            } else {
                error = model.setShortcut(Shortcut(keyCode: event.keyCode, flags: flags), for: target)
            }
            return nil
        }
    }

    private func stopRecording() {
        removeMonitor()
        guard recording != nil else { return }
        recording = nil
        model.resumeShortcuts()
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

enum ResultDecimals {
    static let key = "resultDecimals"
    static let fixedDefault = 2

    static func clamp(_ value: Int) -> Int { min(max(value, 0), NumberParser.maximumDecimals) }

    static func load(from defaults: UserDefaults) -> Int? {
        guard let stored = defaults.object(forKey: key) as? Int, stored >= 0 else { return nil }
        return clamp(stored)
    }
}
