import MathCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var session: CalculatorSession
    @State private var manualText = ""
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("appearance") private var appearance: AppAppearance = .system

    private static let secondaryOperations: [MathCore.Operation] = [.average, .ratio, .change]

    var body: some View {
        Group {
            if !onboardingCompleted {
                OnboardingView(model: model) { onboardingCompleted = true }
            } else if model.compact {
                compactCalculator
            } else {
                calculator
            }
        }
        .foregroundStyle(Design.text)
        .background(Design.canvas)
        .tint(Design.accent)
        .focusEffectDisabled()
        .preferredColorScheme(appearance.colorScheme)
        .onAppear { NSApp.appearance = appearance.nsAppearance }
        .onChange(of: appearance) { _, value in NSApp.appearance = value.nsAppearance }
        .frame(minWidth: model.compact && onboardingCompleted ? 260 : 380,
               minHeight: model.compact && onboardingCompleted ? 230 : 620)
        .sheet(isPresented: $model.reviewScreenCapture) { captureReview }
        .sheet(isPresented: $model.showingSettings) { SettingsView(model: model) }
    }

    private var calculator: some View {
        VStack(spacing: 0) {
            header
            resultCard.padding(.horizontal, Design.inset).padding(.bottom, 12)
            operationPicker.padding(.horizontal, Design.inset).padding(.bottom, 8)
            operandList
            footer
        }
    }

    private var compactCalculator: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Menu {
                    ForEach(MathCore.Operation.allCases) { operation in
                        Button(L("operation." + operation.rawValue)) { session.operation = operation }
                    }
                } label: {
                    Text(session.operation.symbol + "  " + L("operation." + session.operation.rawValue))
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton).fixedSize().focusable(false).focusEffectDisabled()
                .accessibilityLabel(L("operation." + session.operation.rawValue))
                Spacer()
                if session.operation == .change && session.canSwapPair { swapButton }
                copyButton
                iconButton("arrow.up.left.and.arrow.down.right", key: "compact.exit") { model.compact = false }
            }
            resultValue(size: 34)
            if !session.operands.isEmpty {
                VStack(spacing: 2) {
                    ForEach(Array(session.operands.enumerated().suffix(3)), id: \.element.id) { index, operand in
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
                                .foregroundStyle(Design.muted).frame(width: 20)
                            Text(operand.text(style: session.style))
                                .font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit().lineLimit(1)
                            Text(operand.source).font(.system(size: 11)).foregroundStyle(Design.muted).lineLimit(1)
                            Spacer(minLength: 0)
                            iconButton("xmark", key: "remove", kind: .destructive) { session.remove(operand.id) }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button(action: model.captureSelection) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(model.shortcutSymbols(.addSelection)).font(.system(size: 12, design: .rounded))
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(kind: .primary, compact: true))
                .help(L("capture.selection") + " (" + model.shortcutSpoken(.addSelection) + ")")
                .accessibilityLabel(L("capture.selection"))
                iconButton("viewfinder", key: "capture.screen") { model.captureScreen() }
                iconButton("arrow.uturn.backward", key: "undoCapture") { session.undoCapture() }
                    .disabled(session.operands.isEmpty)
                if session.operands.isEmpty && session.canUndoReset {
                    iconButton("arrow.counterclockwise", key: "undoReset", action: model.undoReset)
                } else {
                    iconButton("trash", key: "reset", kind: .destructive, action: model.reset)
                        .disabled(session.operands.isEmpty)
                }
            }.disabled(model.capturing)
            messageSlot
        }
        .padding(14)
    }

    private var captureReview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("capture.reviewTitle")).font(.system(size: 18, weight: .semibold))
            Text(L("capture.reviewOCR")).font(.system(size: 13)).foregroundStyle(Design.muted)
            TextEditor(text: $model.screenText).font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden).padding(10).frame(height: 130).focusEffectDisabled(false)
                .background(Design.surface, in: RoundedRectangle(cornerRadius: 10))
            if model.isError { Text(model.message).font(.caption).foregroundStyle(Design.danger) }
            HStack {
                Button(L("cancel")) { model.reviewScreenCapture = false; model.screenText = "" }
                    .buttonStyle(SoftButtonStyle()).keyboardShortcut(.cancelAction)
                Spacer()
                Button(L("capture.confirm"), action: model.confirmScreenCapture)
                    .buttonStyle(SoftButtonStyle(kind: .primary)).keyboardShortcut(.defaultAction)
                    .disabled(model.screenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 350).foregroundStyle(Design.text).background(Design.canvas)
        .focusEffectDisabled()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("title")).font(.system(size: 18, weight: .semibold))
                    Text(L("subtitle")).font(.system(size: 12)).foregroundStyle(Design.muted)
                }
                Spacer()
                iconButton("arrow.down.right.and.arrow.up.left", key: "compact.enter") { model.compact = true }
                iconButton("gearshape", key: "settings") { model.showingSettings = true }
                iconButton("questionmark", key: "onboarding.show") { onboardingCompleted = false }
            }
            if !model.accessibilityGranted {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "hand.raised").foregroundStyle(.secondary)
                    Text(L("permission.explanation")).font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button(L("permission.grant"), action: model.requestAccessibility)
                        .buttonStyle(SoftButtonStyle(compact: true))
                }
            }
        }
        .padding(Design.inset)
    }

    private var copyButton: some View {
        Button(action: model.copyResult) { Image(systemName: "doc.on.doc") }
            .buttonStyle(SoftButtonStyle(compact: true)).help(L("copyResult"))
            .accessibilityLabel(L("copyResult"))
            .disabled(model.capturing || (try? session.result()) == nil)
    }

    private var swapButton: some View {
        Button(action: session.swapPair) { Image(systemName: "arrow.left.arrow.right") }
            .buttonStyle(SoftButtonStyle(compact: true)).help(L("swapPair"))
            .accessibilityLabel(L("swapPair")).accessibilityIdentifier("swap-pair")
            .disabled(model.capturing)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(L("operation." + session.operation.rawValue)).font(.system(size: 12, weight: .semibold))
                Spacer()
                copyButton
            }
            resultValue(size: 44)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.note, in: RoundedRectangle(cornerRadius: Design.radius, style: .continuous))
    }

    @ViewBuilder
    private func resultValue(size: CGFloat) -> some View {
        if session.operands.isEmpty {
            Text("0").font(.system(size: size, weight: .medium, design: .rounded)).foregroundStyle(Design.muted)
            Text(L("empty.result")).font(.system(size: 12)).foregroundStyle(Design.muted)
        } else {
            switch Result(catching: { try session.result() }) {
            case .success(let result):
                Text(result.text(style: session.style))
                    .font(.system(size: size, weight: .medium, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.35)
                    .textSelection(.enabled).accessibilityIdentifier("calculation-result")
                Text(result.isPercentagePoints ? L("result.percentagePoints") : expression)
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(Design.muted)
                    .lineLimit(2)
            case .failure(let error):
                Text(L("error." + ((error as? MathError)?.rawValue ?? "invalidNumber")))
                    .font(.headline).foregroundStyle(Design.danger).frame(minHeight: size + 4, alignment: .leading)
                Text(L("hint." + session.operation.rawValue)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var expression: String {
        if session.operation == .change { return L("hint.change") }
        if session.operation == .average { return L("hint.average") }
        return Arithmetic.expression(session.operands, operation: session.operation, style: session.style)
    }

    private var operationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach([MathCore.Operation.sum, .difference, .product, .quotient]) { operation in
                    Button { session.operation = operation } label: {
                        Text(operation.symbol).font(.system(size: 20, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(session.operation == operation ? Design.raised : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(session.operation == operation ? Design.accent : Design.muted)
                    }
                    .buttonStyle(FocusRingStyle(radius: 9)).help(L("operation." + operation.rawValue))
                    .accessibilityLabel(L("operation." + operation.rawValue))
                    .accessibilityIdentifier("operation-" + operation.rawValue)
                    .accessibilityAddTraits(session.operation == operation ? .isSelected : [])
                }
                secondaryOperationMenu
            }.padding(5).background(Design.surface, in: RoundedRectangle(cornerRadius: 13))
            if [.difference, .quotient, .ratio, .change].contains(session.operation) {
                HStack(spacing: 8) {
                    Text(L("hint." + session.operation.rawValue)).font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if session.operation == .change && session.canSwapPair { swapButton }
                }
            }
        }
    }

    private var secondaryOperationMenu: some View {
        let active = Self.secondaryOperations.contains(session.operation)
        let label = active ? L("operation." + session.operation.rawValue) : L("operations.more")
        return Menu {
            ForEach(Self.secondaryOperations) { operation in
                Button(L("operation." + operation.rawValue)) { session.operation = operation }
            }
        } label: {
            secondaryOperationLabel(active: active)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().focusable(false).focusEffectDisabled().help(L("operations.more"))
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func secondaryOperationLabel(active: Bool) -> some View {
        Group {
            if active {
                Text(session.operation.symbol).font(.system(size: 18, weight: .medium))
            } else {
                Image(systemName: "ellipsis")
            }
        }
        .frame(width: 36, height: 36)
        .background(active ? Design.raised : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        .foregroundStyle(active ? Design.accent : Design.muted)
    }

    private var operandList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L("operands")).font(.system(size: 12, weight: .semibold))
                Text("\(session.operands.count)").font(.caption.monospacedDigit()).foregroundStyle(Design.muted)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(Design.surface, in: RoundedRectangle(cornerRadius: 6))
                Spacer()
                Button { session.undoCapture() } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(SoftButtonStyle(compact: true)).disabled(session.operands.isEmpty)
                    .help(L("undoCapture")).accessibilityLabel(L("undoCapture"))
                if session.operands.isEmpty && session.canUndoReset {
                    Button(L("undoReset"), action: model.undoReset)
                        .buttonStyle(SoftButtonStyle(compact: true)).accessibilityIdentifier("undo-reset")
                } else {
                    Button(L("reset"), action: model.reset)
                        .buttonStyle(SoftButtonStyle(kind: .destructive, compact: true)).disabled(session.operands.isEmpty)
                        .accessibilityIdentifier("reset")
                }
            }
            .padding(.horizontal, Design.inset).padding(.vertical, 12)
            if session.operands.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "plus.square.on.square").font(.system(size: 25)).foregroundStyle(Design.muted)
                    Text(L("empty.title")).font(.system(size: 13, weight: .medium))
                    Text(String(format: L("empty.description"), model.shortcutSpoken(.addSelection)))
                        .font(.caption).foregroundStyle(Design.muted)
                        .multilineTextAlignment(.center).frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(session.operands.enumerated()), id: \.element.id) { index, operand in
                                OperandRow(operand: operand, index: index, session: session).id(operand.id)
                            }
                        }.padding(.horizontal, Design.inset).padding(.bottom, 8)
                    }
                    .onChange(of: session.operands.count) { oldCount, newCount in
                        if newCount > oldCount, let id = session.operands.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }
        }.frame(minHeight: 130, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(action: model.captureSelection) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(L("capture.selection"))
                        Spacer(minLength: 0)
                        Text(model.shortcutSymbols(.addSelection)).font(.system(size: 11, design: .rounded)).opacity(0.85)
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(kind: .primary))
                .help(model.shortcutSpoken(.addSelection)).accessibilityIdentifier("capture-selection")
                Button(action: model.captureScreen) {
                    Label(L("capture.screen"), systemImage: "viewfinder")
                }.buttonStyle(SoftButtonStyle()).help(model.shortcutSpoken(.captureArea))
            }.disabled(model.capturing)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L("format")).font(.system(size: 12)).foregroundStyle(Design.muted)
                    Spacer()
                    SoftSegmented(options: NumberStyle.allCases.map { ($0, $0.example) }, selection: $session.style,
                                  well: Design.canvas)
                        .frame(width: 170).disabled(model.capturing)
                        .accessibilityLabel(L("format"))
                }
                DisclosureGroup(L("manual")) {
                    HStack {
                        TextField(L("manual.placeholder"), text: $manualText).onSubmit(addManual)
                            .textFieldStyle(.roundedBorder).focusEffectDisabled(false)
                        Button(L("add"), action: addManual).disabled(manualText.isEmpty)
                            .buttonStyle(SoftButtonStyle(compact: true))
                    }.padding(.top, 6)
                }.font(.system(size: 12))
            }.padding(12).background(Design.surface, in: RoundedRectangle(cornerRadius: 12))
            messageSlot
        }.padding(.horizontal, Design.inset).padding(.top, 10).padding(.bottom, 12)
    }

    private var messageSlot: some View {
        HStack(alignment: .center, spacing: 8) {
            if model.capturing { ProgressView().controlSize(.small).accessibilityLabel(L("transfer.busy")) }
            Text(model.capturing && model.message.isEmpty ? L("transfer.busy") : model.message).font(.caption).foregroundStyle(model.isError ? Design.danger : Design.muted)
                .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("status-message")
        }
        .frame(height: 44, alignment: .center)
        .opacity(model.message.isEmpty && !model.capturing ? 0 : 1)
        .accessibilityHidden(model.message.isEmpty && !model.capturing)
    }

    private func iconButton(_ symbol: String, key: String, kind: SoftButtonStyle.Kind = .secondary,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11)).frame(width: 12, height: 28) }
            .buttonStyle(SoftButtonStyle(kind: kind, compact: true)).help(L(key)).accessibilityLabel(L(key))
    }

    private func addManual() {
        if model.accept(manualText, source: L("source.manual"), generation: session.generation) { manualText = "" }
    }
}

private struct OperandRow: View {
    let operand: Operand
    let index: Int
    @ObservedObject var session: CalculatorSession
    @State private var editing = false
    @State private var draft = ""
    @State private var editError = false
    @State private var editStyle: NumberStyle = .english
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
                    .foregroundStyle(Design.muted).frame(width: 20)
                if editing {
                    TextField(L("edit"), text: $draft).textFieldStyle(.roundedBorder).focusEffectDisabled(false)
                        .focused($focused).onSubmit(save)
                        .onExitCommand { editing = false }
                        .accessibilityIdentifier("operand-edit-\(index)")
                    iconButton("checkmark", key: "save", action: save)
                    iconButton("xmark", key: "cancel") { editing = false }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(operand.text(style: session.style))
                            .font(.system(size: 17, weight: .medium, design: .rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(operand.source).font(.system(size: 11)).foregroundStyle(Design.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    iconButton("chevron.up", key: "moveUp") { session.move(operand.id, by: -1) }
                        .disabled(index == 0)
                    iconButton("chevron.down", key: "moveDown") { session.move(operand.id, by: 1) }
                        .disabled(index == session.operands.count - 1)
                    iconButton("pencil", key: "edit") {
                        editStyle = session.style
                        draft = NumberParser.editable(operand, style: editStyle)
                        editing = true
                        editError = false
                        focused = true
                    }
                    iconButton("xmark", key: "remove") { session.remove(operand.id) }
                }
            }
            if editing && editError { Text(L("error.invalidNumber")).font(.caption).foregroundStyle(Design.danger) }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(Design.surface.opacity(index.isMultiple(of: 2) ? 1 : 0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func iconButton(_ symbol: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 11)).frame(width: 12, height: 28) }
            .buttonStyle(SoftButtonStyle(kind: key == "remove" ? .destructive : .secondary, compact: true)).help(L(key))
            .accessibilityLabel(L(key)).accessibilityIdentifier("operand-\(key)-\(index)")
    }

    private func save() {
        do { try session.edit(operand.id, text: draft, style: editStyle); editing = false }
        catch { editError = true }
    }
}
