import Foundation

public enum NYXFilterKind: String, Codable, CaseIterable {
    case keyword      // case-insensitive substring
    case wholeWord    // case-insensitive, word boundaries
    case regex        // NSRegularExpression, validated
}

public enum NYXFilterAction: String, Codable, CaseIterable {
    case hide, highlight, mute
}

public struct NYXFilterRule: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var enabled: Bool
    public var kind: NYXFilterKind
    public var pattern: String
    public var action: NYXFilterAction

    public init(id: UUID = UUID(), name: String, enabled: Bool = true, kind: NYXFilterKind = .keyword, pattern: String, action: NYXFilterAction = .hide) {
        self.id = id; self.name = name; self.enabled = enabled; self.kind = kind; self.pattern = pattern; self.action = action
    }
}

public enum NYXFilterValidation: Equatable {
    case ok
    case emptyPattern
    case tooLong
    case invalidRegex
}

/// Pure rule matcher. It decides what a rule set would do with a text; wiring that decision into the chat
/// UI is a separate step.
public enum NYXMessageFilter {
    public static let maxPatternLength = 200
    public static let maxRules = 100
    public static let maxTextLength = 20_000

    public static func validate(_ rule: NYXFilterRule) -> NYXFilterValidation {
        let pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if pattern.isEmpty { return .emptyPattern }
        if pattern.count > maxPatternLength { return .tooLong }
        if rule.kind == .regex, (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])) == nil {
            return .invalidRegex
        }
        return .ok
    }

    public static func matches(_ rule: NYXFilterRule, in text: String) -> Bool {
        guard rule.enabled, validate(rule) == .ok else { return false }
        let text = String(text.prefix(maxTextLength))
        let pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        switch rule.kind {
        case .keyword:
            return text.range(of: pattern, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        case .wholeWord:
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
            return text.range(of: "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])", options: [.regularExpression, .caseInsensitive]) != nil
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
            return regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil
        }
    }

    /// Strongest action among matching rules: hide > mute > highlight. Nil when nothing matches.
    public static func decide(_ rules: [NYXFilterRule], text: String) -> (action: NYXFilterAction, rule: NYXFilterRule)? {
        let order: [NYXFilterAction] = [.hide, .mute, .highlight]
        var best: (NYXFilterAction, NYXFilterRule)?
        for rule in rules.prefix(maxRules) where matches(rule, in: text) {
            if best == nil || order.firstIndex(of: rule.action)! < order.firstIndex(of: best!.0)! {
                best = (rule.action, rule)
            }
        }
        return best.map { (action: $0.0, rule: $0.1) }
    }
}
