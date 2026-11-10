import Foundation

public struct NYXToolkitPrefs: Codable, Equatable {
    public var filterRules: [NYXFilterRule] = []
    public var redaction = NYXRedactionOptions()
    public init() {}
}

public final class NYXToolkitStore {
    public static let shared = NYXToolkitStore(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NYXGram/toolkit.json"))
    private let file: NYXJSONFile<NYXToolkitPrefs>
    public init(url: URL) { self.file = NYXJSONFile(url: url, defaultValue: NYXToolkitPrefs()) }
    public var prefs: NYXToolkitPrefs { return self.file.value }
    public var wasRecovered: Bool { return self.file.recovered }

    /// Rule limits are enforced here, so the UI cannot store an invalid rule set.
    @discardableResult
    public func addRule(_ rule: NYXFilterRule) -> NYXFilterValidation {
        let check = NYXMessageFilter.validate(rule)
        guard check == .ok, self.prefs.filterRules.count < NYXMessageFilter.maxRules else {
            return check == .ok ? .tooLong : check
        }
        self.file.update { $0.filterRules.append(rule) }
        return .ok
    }

    public func update(_ change: (inout NYXToolkitPrefs) -> Void) { self.file.update(change) }
}
