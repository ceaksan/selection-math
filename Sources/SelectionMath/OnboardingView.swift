import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, access, shortcut
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var titleKey: String { "onboarding.\(self).title" }
    var detailKey: String { "onboarding.\(self).detail" }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    let finish: () -> Void
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("title")).font(.system(size: 13, weight: .medium)).foregroundStyle(Design.muted)
                Spacer()
                Button(L("onboarding.skip"), action: finish).buttonStyle(SoftButtonStyle(compact: true))
            }.padding(24)
            hero
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 14) {
                Text(L(step.titleKey)).font(.system(size: 25, weight: .semibold)).tracking(-0.5)
                Text(detail).font(.system(size: 14)).foregroundStyle(Design.muted)
                    .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                if step == .access {
                    if model.accessibilityGranted {
                        Label(L("onboarding.access.ready"), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Design.accent)
                    } else {
                        Button(L("permission.grant"), action: model.requestAccessibility)
                            .buttonStyle(SoftButtonStyle())
                        Text(L("onboarding.access.optional")).font(.system(size: 12)).foregroundStyle(Design.muted)
                    }
                }
            }.padding(.horizontal, 28)
            Spacer(minLength: 24)
            HStack {
                if step != .welcome {
                    Button(L("onboarding.back")) {
                        step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
                    }.buttonStyle(SoftButtonStyle())
                }
                Spacer()
                Button(L(step.next == nil ? "onboarding.start" : "onboarding.continue")) {
                    if let next = step.next { step = next } else { finish() }
                }.buttonStyle(SoftButtonStyle(kind: .primary))
            }.padding(.horizontal, 28)
            HStack(spacing: 7) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                    Circle().fill(item == step ? Design.text : Design.border).frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: L("onboarding.progress"), step.rawValue + 1, OnboardingStep.allCases.count))
        }
        .foregroundStyle(Design.text).background(Design.canvas)
    }

    private var detail: String {
        step == .shortcut ? String(format: L(step.detailKey), model.shortcutSpoken(.addSelection)) : L(step.detailKey)
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.16), Color.blue.opacity(0.20), Color.purple.opacity(0.12), Design.canvas],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if step == .shortcut {
                HStack(spacing: 10) {
                    ForEach(Array(model.shortcutParts(.addSelection).enumerated()), id: \.offset) { _, part in
                        Keycap(label: part, large: true)
                    }
                }
            } else {
                Image(systemName: step == .welcome ? "sum" : "hand.raised")
                    .font(.system(size: 46, weight: .medium)).foregroundStyle(Design.accent)
                    .frame(width: 110, height: 110)
                    .background(Design.raised, in: RoundedRectangle(cornerRadius: 30))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
            }
        }
        .frame(height: 210).padding(.horizontal, 20).accessibilityHidden(true)
    }
}
