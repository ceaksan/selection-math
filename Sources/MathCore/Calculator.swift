import Combine
import Foundation

public enum NumberStyle: String, CaseIterable, Identifiable {
    case english, turkish
    public var id: String { rawValue }
    public var locale: Locale { Locale(identifier: self == .english ? "en_US" : "tr_TR") }
    public var example: String { self == .english ? "1,234.56" : "1.234,56" }
}

public enum MathError: String, Error {
    case noNumbers, invalidNumber, tooManyNumbers, needsTwo, zeroDivision, overflow, missingOperand
}

public struct Operand: Identifiable, Equatable {
    public let id: UUID
    public var value: Decimal
    public var isPercent: Bool
    public var source: String

    public init(value: Decimal, isPercent: Bool = false, source: String = "", id: UUID = UUID()) {
        self.id = id
        self.value = value
        self.isPercent = isPercent
        self.source = source
    }

    public func text(style: NumberStyle) -> String {
        NumberParser.format(isPercent ? value * 100 : value, style: style) + (isPercent ? "%" : "")
    }
}

public enum NumberParser {
    public static func parse(_ text: String, style: NumberStyle, source: String = "") throws -> [Operand] {
        try scan(text, style: style, source: source).operands
    }

    public static func scan(_ text: String, style: NumberStyle,
                            source: String = "") throws -> (operands: [Operand], skipped: [String]) {
        let found = try matches(text, style: style)
        guard !found.isEmpty else { throw MathError.noNumbers }
        guard found.count <= CalculatorSession.maximumOperands else { throw MathError.tooManyNumbers }
        let operands = try found.map { try operand(String(text[$0]), style: style, source: source) }
        return (operands, skipped(in: text, matched: found))
    }

    public static func single(_ text: String, style: NumberStyle) throws -> Operand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = try matches(trimmed, style: style)
        guard found.count == 1, trimmed[found[0]] == trimmed else { throw MathError.invalidNumber }
        return try operand(trimmed, style: style, source: "")
    }

    private static func matches(_ text: String, style: NumberStyle) throws -> [Range<String.Index>] {
        guard text.utf8.count <= 32_768 else { throw MathError.tooManyNumbers }
        let group = style == .english ? "," : "\\."
        let point = style == .english ? "\\." : ","
        let dottedDecimal = style == .turkish ? "|[0-9]+\\.[0-9]+|\\.[0-9]+" : ""
        let digits = "(?:[0-9]{1,3}(?:\(group)[0-9]{3})+(?:\(point)[0-9]+)?\(dottedDecimal)|[0-9]+(?:\(point)[0-9]+)?|\(point)[0-9]+)"
        let number = "\(digits)(?:[eE][-+]?[0-9]+)?"
        let percent = "(?:[ \\t]*%)?"
        let prefix = "(?:[-+−][ ]?(?:\\p{Sc}[ ]?)?|\\p{Sc}[ ]?[-+−]?)?"
        let parenthesized = "\\((?:\\p{Sc}[ ]?)?\(number)\(percent)\\)"
        let pattern = "(?<![\\p{L}\\p{N}_.])(?:\(parenthesized)|\(prefix)\(number)\(percent))(?![\\p{L}\\p{N}_.])"
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text) }
    }

    private static func skipped(in text: String, matched: [Range<String.Index>]) -> [String] {
        guard let chunks = try? NSRegularExpression(pattern: "[^\\s|]*\\p{N}[^\\s|]*") else { return [] }
        return chunks.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { result in
            guard let range = Range(result.range, in: text), !matched.contains(where: { $0.overlaps(range) }) else { return nil }
            return String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ",.;:"))
        }
    }

    private static func operand(_ raw: String, style: NumberStyle, source: String) throws -> Operand {
        let parenthesized = raw.hasPrefix("(") && raw.hasSuffix(")")
        let body = parenthesized ? String(raw.dropFirst().dropLast()) : raw
        let percent = body.contains("%")
        var normalized = body
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "[\\p{Sc}%\\s]", with: "", options: .regularExpression)
        let validTurkishGrouping = normalized.range(of: "^[-+]?[0-9]{1,3}(?:\\.[0-9]{3})+$", options: .regularExpression) != nil
        let dotIsDecimal = style == .turkish && normalized.contains(".") && !normalized.contains(",") && !validTurkishGrouping
        if style == .english || dotIsDecimal {
            normalized = normalized.replacingOccurrences(of: ",", with: "")
        } else {
            normalized = normalized.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        guard var value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN else { throw MathError.invalidNumber }
        if parenthesized { value = -value }
        return Operand(value: percent ? try Arithmetic.divide(value, 100) : value,
                       isPercent: percent, source: source)
    }

    private static let formatters: [NumberStyle: NumberFormatter] = Dictionary(uniqueKeysWithValues: NumberStyle.allCases.map { style in
        let formatter = NumberFormatter()
        formatter.locale = style.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        return (style, formatter)
    })

    public static func format(_ value: Decimal, style: NumberStyle) -> String {
        let number = NSDecimalNumber(decimal: value)
        return formatters[style]?.string(from: number) ?? number.stringValue
    }

    public static func editable(_ operand: Operand, style: NumberStyle) -> String {
        let value = operand.isPercent ? operand.value * 100 : operand.value
        var text = NSDecimalNumber(decimal: value).stringValue
        if style == .turkish { text = text.replacingOccurrences(of: ".", with: ",") }
        return text + (operand.isPercent ? "%" : "")
    }
}

public enum Operation: String, CaseIterable, Identifiable {
    case sum, difference, product, quotient, average, ratio, change
    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .sum: return "+"
        case .difference: return "−"
        case .product: return "×"
        case .quotient, .ratio: return "÷"
        case .average: return "x̄"
        case .change: return "%"
        }
    }
}

public struct Calculation {
    public let value: Decimal
    public let isPercent: Bool
    public let isPercentagePoints: Bool

    public func text(style: NumberStyle) -> String {
        if isPercentagePoints { return copyText(style: style) + " pp" }
        return NumberParser.format(isPercent ? value * 100 : value, style: style) + (isPercent ? "%" : "")
    }

    public func copyText(style: NumberStyle) -> String {
        isPercentagePoints ? NumberParser.format(value * 100, style: style) : text(style: style)
    }
}

public enum Arithmetic {
    private static func evaluate(
        _ lhs: Decimal, _ rhs: Decimal,
        using function: (UnsafeMutablePointer<Decimal>, UnsafePointer<Decimal>, UnsafePointer<Decimal>, Decimal.RoundingMode) -> Decimal.CalculationError
    ) throws -> Decimal {
        var left = lhs
        var right = rhs
        var result = Decimal()
        let status = function(&result, &left, &right, .plain)
        guard status == .noError || status == .lossOfPrecision, !result.isNaN else {
            throw status == .divideByZero ? MathError.zeroDivision : MathError.overflow
        }
        return result
    }

    public static func divide(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        guard rhs != 0 else { throw MathError.zeroDivision }
        return try evaluate(lhs, rhs, using: NSDecimalDivide)
    }

    public static func expression(_ operands: [Operand], operation: Operation, style: NumberStyle) -> String {
        let minus = Operation.difference.symbol
        func magnitude(_ operand: Operand) -> String {
            var positive = operand
            positive.value = operand.value < 0 ? -operand.value : operand.value
            return positive.text(style: style)
        }
        func signed(_ operand: Operand) -> String { (operand.value < 0 ? minus : "") + magnitude(operand) }
        guard let first = operands.first else { return "" }
        return operands.dropFirst().reduce(signed(first)) { text, operand in
            let negative = operand.value < 0
            switch operation {
            case .sum: return text + (negative ? " \(minus) " : " + ") + magnitude(operand)
            case .difference: return text + (negative ? " + " : " \(minus) ") + magnitude(operand)
            default: return text + " \(operation.symbol) " + (negative ? "(\(signed(operand)))" : magnitude(operand))
            }
        }
    }

    public static func calculate(_ operands: [Operand], operation: Operation) throws -> Calculation {
        guard let first = operands.first else { throw MathError.noNumbers }
        let values = operands.map(\.value)
        let percent = operands.allSatisfy(\.isPercent)
        var value = first.value
        switch operation {
        case .sum, .average:
            value = try values.reduce(Decimal.zero) { try evaluate($0, $1, using: NSDecimalAdd) }
            if operation == .average { value = try divide(value, Decimal(values.count)) }
        case .difference:
            value = try values.dropFirst().reduce(value) { try evaluate($0, $1, using: NSDecimalSubtract) }
        case .product:
            value = try values.dropFirst().reduce(value) { try evaluate($0, $1, using: NSDecimalMultiply) }
        case .quotient:
            value = try values.dropFirst().reduce(value) { try divide($0, $1) }
        case .ratio:
            guard values.count == 2 else { throw MathError.needsTwo }
            value = try divide(values[0], values[1])
        case .change:
            guard values.count == 2 else { throw MathError.needsTwo }
            value = try divide(evaluate(values[1], values[0], using: NSDecimalSubtract), values[0])
        }
        let percentResult = operation == .change || (percent && [.sum, .difference, .average].contains(operation))
        if percentResult { _ = try evaluate(value, 100, using: NSDecimalMultiply) }
        return Calculation(value: value, isPercent: percentResult,
                           isPercentagePoints: percent && operation == .difference)
    }
}

public struct Acceptance: Equatable {
    public let accepted: Bool
    public let skipped: [String]
}

@MainActor
public final class CalculatorSession: ObservableObject {
    nonisolated public static let maximumOperands = 100
    @Published public private(set) var operands: [Operand] = []
    @Published public var operation: Operation = .sum
    @Published public var style: NumberStyle = .english
    @Published public private(set) var generation: UInt = 0
    @Published public private(set) var canUndoReset = false
    private var batches: [[UUID]] = []
    private var resetSnapshot: (operands: [Operand], batches: [[UUID]], operation: Operation)? {
        didSet { canUndoReset = resetSnapshot != nil }
    }

    public init() {}

    @discardableResult
    public func accept(_ text: String, source: String, generation expected: UInt) throws -> Acceptance {
        guard expected == generation else { return Acceptance(accepted: false, skipped: []) }
        let (incoming, skipped) = try NumberParser.scan(text, style: style, source: source)
        guard operands.count + incoming.count <= Self.maximumOperands else { throw MathError.tooManyNumbers }
        operands.append(contentsOf: incoming)
        batches.append(incoming.map(\.id))
        resetSnapshot = nil
        return Acceptance(accepted: true, skipped: skipped)
    }

    public func edit(_ id: UUID, text: String, style editStyle: NumberStyle? = nil) throws {
        guard let index = operands.firstIndex(where: { $0.id == id }) else { throw MathError.missingOperand }
        let parsed = try NumberParser.single(text, style: editStyle ?? style)
        operands[index].value = parsed.value
        operands[index].isPercent = parsed.isPercent
        resetSnapshot = nil
    }

    public func remove(_ id: UUID) {
        operands.removeAll { $0.id == id }
        resetSnapshot = nil
    }

    public func move(_ id: UUID, by offset: Int) {
        guard let index = operands.firstIndex(where: { $0.id == id }),
              operands.indices.contains(index + offset) else { return }
        operands.swapAt(index, index + offset)
        resetSnapshot = nil
    }

    public func undoCapture() {
        resetSnapshot = nil
        while let ids = batches.popLast() {
            if operands.contains(where: { ids.contains($0.id) }) {
                operands.removeAll { ids.contains($0.id) }
                return
            }
        }
    }

    public func reset() {
        if !operands.isEmpty { resetSnapshot = (operands, batches, operation) }
        generation &+= 1
        operands.removeAll()
        batches.removeAll()
        operation = .sum
    }

    public func undoReset() {
        guard let snapshot = resetSnapshot else { return }
        operands = snapshot.operands
        batches = snapshot.batches
        operation = snapshot.operation
        resetSnapshot = nil
    }

    public func result() throws -> Calculation {
        try Arithmetic.calculate(operands, operation: operation)
    }
}
