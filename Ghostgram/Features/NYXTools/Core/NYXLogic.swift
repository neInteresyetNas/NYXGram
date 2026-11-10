import Foundation

// MARK: Filter engine

public enum NYXFilterEngine {
    /// nil when the pattern is valid, otherwise a short reason.
    public static func validate(_ rule: NYXFilterRule) -> String? {
        if rule.pattern.isEmpty { return "empty" }
        if rule.pattern.count > NYXToolsPrefs.maxPatternLength { return "too long" }
        if rule.isRegex, (try? NSRegularExpression(pattern: rule.pattern, options: [])) == nil { return "invalid regex" }
        return nil
    }

    public static func matches(_ rule: NYXFilterRule, in text: String) -> Bool {
        guard rule.enabled, validate(rule) == nil else { return false }
        if rule.isRegex {
            let options: NSRegularExpression.Options = rule.caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: options) else { return false }
            // Long inputs are cut so a heavy pattern can not stall the UI.
            let sample = String(text.prefix(5000))
            return regex.firstMatch(in: sample, options: [], range: NSRange(sample.startIndex..., in: sample)) != nil
        }
        return rule.caseSensitive ? text.contains(rule.pattern) : text.range(of: rule.pattern, options: .caseInsensitive) != nil
    }

    /// Rules that match, in list order.
    public static func matching(_ rules: [NYXFilterRule], text: String) -> [NYXFilterRule] {
        return rules.filter { NYXFilterEngine.matches($0, in: text) }
    }

    /// The strongest action among the matches: hide > mute > highlight.
    public static func decision(_ rules: [NYXFilterRule], text: String) -> NYXFilterAction? {
        let actions = Set(NYXFilterEngine.matching(rules, text: text).map { $0.action })
        for action in [NYXFilterAction.hide, .mute, .highlight] where actions.contains(action) { return action }
        return nil
    }
}

// MARK: Redaction (Streamer mode preview and a "copy safe text" tool)

public struct NYXRedactionOptions: Codable, Equatable {
    public var phones = true
    public var emails = true
    public var cards = true
    public var links = false
    public init() {}
}

public enum NYXRedactor {
    private static func regex(_ pattern: String) -> NSRegularExpression? {
        return try? NSRegularExpression(pattern: pattern, options: [])
    }

    public static func redact(_ text: String, options: NYXRedactionOptions) -> String {
        var result = text
        if options.cards { result = NYXRedactor.maskCards(result) }
        if options.emails { result = NYXRedactor.replace(result, pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", with: "•••@•••") }
        if options.links { result = NYXRedactor.replace(result, pattern: "(https?://|t\\.me/)[^\\s]+", with: "[link hidden]") }
        if options.phones { result = NYXRedactor.replace(result, pattern: "\\+?\\d[\\d\\s().-]{7,}\\d", with: "+••• ••• ••••") }
        return result
    }

    private static func replace(_ text: String, pattern: String, with template: String) -> String {
        guard let regex = NYXRedactor.regex(pattern) else { return text }
        return regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: NSRegularExpression.escapedTemplate(for: template))
    }

    /// Card numbers: 13–19 digits (spaces/dashes allowed) that pass the Luhn check.
    private static func maskCards(_ text: String) -> String {
        guard let regex = NYXRedactor.regex("\\b(?:\\d[ -]?){12,18}\\d\\b") else { return text }
        var result = text
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let digits = result[range].filter { $0.isNumber }
            if (13...19).contains(digits.count), luhn(String(digits)) {
                result.replaceSubrange(range, with: "•••• •••• •••• " + digits.suffix(4))
            }
        }
        return result
    }

    static func luhn(_ digits: String) -> Bool {
        var sum = 0
        for (index, character) in digits.reversed().enumerated() {
            guard var value = character.wholeNumberValue else { return false }
            if index % 2 == 1 {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
        }
        return sum % 10 == 0
    }
}

// MARK: Templates

public enum NYXTemplateRenderer {
    /// Replaces {date}, {time}, {weekday} and {name}. Unknown placeholders stay as they are.
    public static func render(_ body: String, now: Date, name: String = "", calendar: Calendar = .current, locale: Locale = .current) -> String {
        let date = DateFormatter(); date.locale = locale; date.calendar = calendar; date.dateStyle = .medium; date.timeStyle = .none
        let time = DateFormatter(); time.locale = locale; time.calendar = calendar; time.dateStyle = .none; time.timeStyle = .short
        let weekday = DateFormatter(); weekday.locale = locale; weekday.calendar = calendar; weekday.dateFormat = "EEEE"
        return body
            .replacingOccurrences(of: "{date}", with: date.string(from: now))
            .replacingOccurrences(of: "{time}", with: time.string(from: now))
            .replacingOccurrences(of: "{weekday}", with: weekday.string(from: now))
            .replacingOccurrences(of: "{name}", with: name)
    }
}
