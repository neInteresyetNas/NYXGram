import Foundation

// MARK: Event log

public struct NYXEvent: Codable, Equatable {
    public enum Category: String, Codable, CaseIterable { case security, privacy, data, filters, system }
    public var date: Date
    public var category: Category
    public var text: String
    public init(date: Date, category: Category, text: String) {
        self.date = date
        self.category = category
        self.text = text
    }
}

// MARK: Filter rules

public enum NYXFilterAction: String, Codable, CaseIterable { case highlight, mute, hide }

public struct NYXFilterRule: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var pattern: String
    public var isRegex: Bool
    public var caseSensitive: Bool
    public var action: NYXFilterAction
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, pattern: String, isRegex: Bool = false, caseSensitive: Bool = false, action: NYXFilterAction = .highlight, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.isRegex = isRegex
        self.caseSensitive = caseSensitive
        self.action = action
        self.enabled = enabled
    }
}

// MARK: Templates

public struct NYXTemplate: Codable, Equatable, Identifiable {
    public var id: UUID
    public var title: String
    public var body: String
    public init(id: UUID = UUID(), title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

// MARK: Prefs

public struct NYXToolsPrefs: Codable, Equatable {
    public static let maxEvents = 500
    public static let maxRules = 100
    public static let maxTemplates = 100
    public static let maxPatternLength = 200
    public static let maxBodyLength = 4000

    public var events: [NYXEvent] = []
    public var rules: [NYXFilterRule] = []
    public var templates: [NYXTemplate] = []
    public var redaction: NYXRedactionOptions = NYXRedactionOptions()

    public init() {}

    public static func normalize(_ prefs: inout NYXToolsPrefs) {
        if prefs.events.count > maxEvents { prefs.events = Array(prefs.events.suffix(maxEvents)) }
        if prefs.rules.count > maxRules { prefs.rules = Array(prefs.rules.prefix(maxRules)) }
        for index in prefs.rules.indices where prefs.rules[index].pattern.count > maxPatternLength {
            prefs.rules[index].pattern = String(prefs.rules[index].pattern.prefix(maxPatternLength))
        }
        if prefs.templates.count > maxTemplates { prefs.templates = Array(prefs.templates.prefix(maxTemplates)) }
        for index in prefs.templates.indices where prefs.templates[index].body.count > maxBodyLength {
            prefs.templates[index].body = String(prefs.templates[index].body.prefix(maxBodyLength))
        }
    }
}

/// Convenience wrapper with the app-wide file location.
public final class NYXToolsStore {
    public static let shared = NYXToolsStore(fileURL: NYXToolsStore.defaultURL())
    public let store: NYXJSONFileStore<NYXToolsPrefs>

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NYXGram", isDirectory: true)
        return base.appendingPathComponent("tools.json")
    }

    public init(fileURL: URL) {
        self.store = NYXJSONFileStore(fileURL: fileURL, defaultValue: NYXToolsPrefs())
    }

    public var current: NYXToolsPrefs { return self.store.current }

    public func update(_ change: (inout NYXToolsPrefs) -> Void) {
        self.store.update(normalize: NYXToolsPrefs.normalize, change)
    }

    public func log(_ category: NYXEvent.Category, _ text: String, now: Date = Date()) {
        self.update { $0.events.append(NYXEvent(date: now, category: category, text: text)) }
    }
}
