import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum About {
    static let author = "Ceyhun Aksan"
    static let links: [(key: String, symbol: String, label: String, url: URL)] = [
        ("about.website", "globe", "ceaksan.com", URL(string: "https://ceaksan.com")!),
        ("about.github", "chevron.left.forwardslash.chevron.right", "github.com/ceaksan", URL(string: "https://github.com/ceaksan")!),
        ("about.x", "at", "@ceaksan", URL(string: "https://x.com/ceaksan")!),
        ("about.source", "shippingbox", "selection-math", URL(string: "https://github.com/ceaksan/selection-math")!)
    ]
    static let coffee = URL(string: "https://buymeacoffee.com/aob4huniy")!
}

enum AppVersion {
    static var label: String { label(bundle: .main) }
    static func label(bundle: Bundle) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "v\(version) (\($0))" } ?? version
    }
}

enum Design {
    static let inset: CGFloat = 20
    static let radius: CGFloat = 16
    static let canvas = adaptive(0xFFFFFF, 0x202125)
    static let surface = adaptive(0xF3F5F6, 0x2C2E34)
    static let raised = adaptive(0xFFFFFF, 0x3B3E46)
    static let text = adaptive(0x202124, 0xF4F5F7)
    static let muted = adaptive(0x626975, 0xB3B8C2)
    static let border = adaptive(0xE5E8EB, 0x484C55)
    static let note = adaptive(0xFAF6E9, 0x32312D)
    static let accent = adaptive(0x006DDB, 0x66B5FF)
    static let action = Color(nsColor: rgb(0x0070DF))
    static let focus = accent.opacity(0.45)
    static let danger = adaptive(0xB9233B, 0xFF8D9C)

    static var windowColor: NSColor { NSColor(canvas) }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            rgb(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }

    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .secondary
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        SoftButton(configuration: configuration, kind: kind, compact: compact)
    }

    private struct SoftButton: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let compact: Bool
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused

        private var fill: Color {
            switch kind {
            case .primary: return Design.action
            case .secondary: return Design.surface
            case .destructive: return Design.danger.opacity(0.09)
            }
        }

        var body: some View {
            configuration.label
                .font(.system(size: compact ? 12 : 13, weight: .medium))
                .padding(.horizontal, compact ? 10 : 14)
                .frame(minHeight: compact ? 28 : 40)
                .foregroundStyle(kind == .primary ? Color.white : kind == .destructive ? Design.danger : Design.text)
                .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(focused ? Design.focus : Design.border.opacity(kind == .secondary ? 0.65 : 0)))
                .overlay(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(configuration.isPressed ? 0.09 : 0)))
                .shadow(color: .black.opacity(kind == .primary && enabled ? 0.09 : 0), radius: 3, y: 2)
                .opacity(enabled ? 1 : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SoftSegmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var well: Color = Design.surface

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        .frame(maxWidth: .infinity).frame(height: 26)
                        .background(selected ? Design.raised : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(selected ? Design.accent : Design.muted)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FocusRingStyle(radius: 7))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(well, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct FocusRingStyle: ButtonStyle {
    var radius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        FocusRing(configuration: configuration, radius: radius)
    }

    private struct FocusRing: View {
        let configuration: ButtonStyleConfiguration
        let radius: CGFloat
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(focused ? Design.focus : Color.clear))
                .opacity(configuration.isPressed ? 0.75 : 1)
        }
    }
}

struct Keycap: View {
    let label: String
    var large = false

    var body: some View {
        Text(label).font(.system(size: large ? 28 : 11, weight: .medium, design: .rounded))
            .foregroundStyle(Design.muted)
            .frame(minWidth: large ? 58 : 20, minHeight: large ? 64 : 22)
            .padding(.horizontal, large ? 8 : 3)
            .background(Design.raised, in: RoundedRectangle(cornerRadius: large ? 18 : 5))
            .overlay(RoundedRectangle(cornerRadius: large ? 18 : 5).strokeBorder(Design.border.opacity(0.7)))
            .shadow(color: .black.opacity(0.06), radius: large ? 6 : 1, y: large ? 3 : 1)
            .accessibilityHidden(true)
    }
}
