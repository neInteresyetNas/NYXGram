import Foundation

public enum NYXEventSeverity: String, Codable, CaseIterable {
    case info, notice, warning
}

public struct NYXEvent: Codable, Equatable {
    public var date: Date
    public var severity: NYXEventSeverity
    public var source: String
    public var text: String
    public init(date: Date, severity: NYXEventSeverity, source: String, text: String) {
        self.date = date; self.severity = severity; self.source = source; self.text = text
    }
}

public struct NYXEventLogData: Codable, Equatable {
    public var events: [NYXEvent] = []
    public init() {}
}

/// Local event log of what NYXGram features did ("Gifts: pinned X", "Import: settings restored").
/// Capped; text is cut so the log can never grow without bound. It stays on the device.
public final class NYXEventLog {
    public static let maxEvents = 500
    public static let maxTextLength = 300
    public static let shared = NYXEventLog(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NYXGram/event-log.json"))

    private let file: NYXJSONFile<NYXEventLogData>

    public init(url: URL) {
        self.file = NYXJSONFile(url: url, defaultValue: NYXEventLogData())
    }

    public var events: [NYXEvent] { return self.file.value.events }
    public var wasRecovered: Bool { return self.file.recovered }

    public func record(_ severity: NYXEventSeverity = .info, source: String, _ text: String, now: Date = Date()) {
        let event = NYXEvent(date: now, severity: severity, source: String(source.prefix(40)), text: String(text.prefix(NYXEventLog.maxTextLength)))
        self.file.update { data in
            data.events.append(event)
            if data.events.count > NYXEventLog.maxEvents {
                data.events.removeFirst(data.events.count - NYXEventLog.maxEvents)
            }
        }
    }

    public func clear() {
        self.file.update { $0.events = [] }
    }

    /// Newest first, optionally limited to a severity and a search text.
    public func query(severity: NYXEventSeverity? = nil, search: String = "") -> [NYXEvent] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        return self.events.reversed().filter { event in
            if let severity = severity, event.severity != severity { return false }
            if needle.isEmpty { return true }
            return event.text.lowercased().contains(needle) || event.source.lowercased().contains(needle)
        }
    }
}
