import Foundation

public struct NYXRedactionOptions: Codable, Equatable {
    public var phones = true
    public var emails = true
    public var links = true
    public var cardNumbers = true
    public var usernames = false
    public init() {}
}

/// Masks sensitive-looking text for Streamer Mode. Purely textual: it works on strings it is given.
public enum NYXRedactor {
    public static let mask = "••••"

    public static func redact(_ text: String, options: NYXRedactionOptions = NYXRedactionOptions()) -> String {
        var result = text
        // Order matters: links and emails first so their digits/@ are not re-matched.
        if options.links { result = replace(result, #"(?i)\b(?:https?://|www\.|t\.me/)[^\s<>"']+"#) }
        if options.emails { result = replace(result, #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#) }
        if options.cardNumbers { result = replaceCards(result) }
        if options.phones { result = replace(result, #"(?<![\w])\+?\d[\d\-\s().]{8,16}\d(?![\w])"#) }
        if options.usernames { result = replace(result, #"(?<![\w@])@[A-Za-z][A-Za-z0-9_]{4,31}"#) }
        return result
    }

    private static func replace(_ text: String, _ pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        return regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: mask)
    }

    /// 13–19 digits (spaces/dashes allowed) that pass the Luhn check.
    private static func replaceCards(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\d)(?:\d[ \-]?){12,18}\d(?!\d)"#, options: []) else { return text }
        let ns = text as NSString
        var result = text as String
        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)).reversed() {
            let candidate = ns.substring(with: match.range)
            let digits = candidate.filter { $0.isNumber }
            if luhn(digits), let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: mask)
            }
        }
        return result
    }

    static func luhn(_ digits: String) -> Bool {
        guard digits.count >= 13, digits.count <= 19 else { return false }
        var sum = 0
        for (index, char) in digits.reversed().enumerated() {
            guard var value = char.wholeNumberValue else { return false }
            if index % 2 == 1 { value *= 2; if value > 9 { value -= 9 } }
            sum += value
        }
        return sum % 10 == 0
    }
}
