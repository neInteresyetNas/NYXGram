import XCTest
@testable import GGNYXToolkitCore

final class NYXToolkitTests: XCTestCase {
    private func tempURL() -> URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("nyx-toolkit-\(UUID().uuidString)/f.json")
    }

    // MARK: filters
    func testKeywordIsCaseAndDiacriticInsensitive() {
        let rule = NYXFilterRule(name: "r", pattern: "cafe")
        XCTAssertTrue(NYXMessageFilter.matches(rule, in: "Nice CAFÉ here"))
        XCTAssertFalse(NYXMessageFilter.matches(rule, in: "tea"))
    }

    func testWholeWordDoesNotMatchInsideWords() {
        let rule = NYXFilterRule(name: "r", kind: .wholeWord, pattern: "cat")
        XCTAssertTrue(NYXMessageFilter.matches(rule, in: "a cat sat"))
        XCTAssertFalse(NYXMessageFilter.matches(rule, in: "category"))
        XCTAssertTrue(NYXMessageFilter.matches(NYXFilterRule(name: "r", kind: .wholeWord, pattern: "c++"), in: "I like c++ a lot"))
    }

    func testInvalidRegexIsRejectedAndNeverMatches() {
        let rule = NYXFilterRule(name: "r", kind: .regex, pattern: "([")
        XCTAssertEqual(NYXMessageFilter.validate(rule), .invalidRegex)
        XCTAssertFalse(NYXMessageFilter.matches(rule, in: "(["))
    }

    func testValidationLimits() {
        XCTAssertEqual(NYXMessageFilter.validate(NYXFilterRule(name: "r", pattern: "  ")), .emptyPattern)
        XCTAssertEqual(NYXMessageFilter.validate(NYXFilterRule(name: "r", pattern: String(repeating: "a", count: 201))), .tooLong)
    }

    func testDisabledRuleDoesNotMatch() {
        XCTAssertFalse(NYXMessageFilter.matches(NYXFilterRule(name: "r", enabled: false, pattern: "x"), in: "x"))
    }

    func testStrongestActionWins() {
        let rules = [
            NYXFilterRule(name: "a", pattern: "spam", action: .highlight),
            NYXFilterRule(name: "b", pattern: "spam", action: .hide),
            NYXFilterRule(name: "c", pattern: "spam", action: .mute)
        ]
        XCTAssertEqual(NYXMessageFilter.decide(rules, text: "spam")?.action, .hide)
        XCTAssertNil(NYXMessageFilter.decide(rules, text: "ok"))
    }

    // MARK: redactor
    func testRedactsEmailLinkAndPhone() {
        let text = "mail me a.b@example.com or see https://example.com/x?y=1 call +49 151 2345 6789"
        let out = NYXRedactor.redact(text)
        XCTAssertFalse(out.contains("example.com"))
        XCTAssertFalse(out.contains("2345"))
        XCTAssertTrue(out.contains(NYXRedactor.mask))
        XCTAssertTrue(out.hasPrefix("mail me"))
    }

    func testCardNumbersNeedLuhn() {
        XCTAssertFalse(NYXRedactor.redact("pay 4242 4242 4242 4242 now", options: onlyCards()).contains("4242"))
        XCTAssertTrue(NYXRedactor.redact("id 1234 5678 9012 3456", options: onlyCards()).contains("1234"))
    }

    func testOptionsCanBeSwitchedOff() {
        var options = NYXRedactionOptions()
        options.emails = false
        XCTAssertTrue(NYXRedactor.redact("a@b.com", options: options).contains("a@b.com"))
        options.usernames = true
        XCTAssertFalse(NYXRedactor.redact("ping @someone_1 please", options: options).contains("someone"))
    }

    private func onlyCards() -> NYXRedactionOptions {
        var o = NYXRedactionOptions()
        o.phones = false; o.emails = false; o.links = false
        return o
    }

    // MARK: event log + json file
    func testEventLogIsCappedAndNewestFirst() {
        let log = NYXEventLog(url: self.tempURL())
        for i in 0..<(NYXEventLog.maxEvents + 5) { log.record(source: "t", "e\(i)") }
        XCTAssertEqual(log.events.count, NYXEventLog.maxEvents)
        XCTAssertEqual(log.query().first?.text, "e\(NYXEventLog.maxEvents + 4)")
    }

    func testEventTextIsCutAndSearchWorks() {
        let log = NYXEventLog(url: self.tempURL())
        log.record(.warning, source: "Gifts", String(repeating: "x", count: 1000))
        log.record(source: "Import", "restored")
        XCTAssertEqual(log.events.first?.text.count, NYXEventLog.maxTextLength)
        XCTAssertEqual(log.query(severity: .warning).count, 1)
        XCTAssertEqual(log.query(search: "REST").count, 1)
    }

    func testPersistenceAndCorruptionRecovery() throws {
        let url = self.tempURL()
        let log = NYXEventLog(url: url)
        log.record(source: "a", "one")
        log.record(source: "a", "two")
        try Data("broken".utf8).write(to: url)
        let reloaded = NYXEventLog(url: url)
        XCTAssertTrue(reloaded.wasRecovered)
        XCTAssertEqual(reloaded.events.count, 1)   // restored from the backup of the previous good save
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)) ?? []
        XCTAssertTrue(names.contains(where: { $0.contains("corrupt-") }))
    }

    func testStoreRejectsInvalidRules() {
        let store = NYXToolkitStore(url: self.tempURL())
        XCTAssertEqual(store.addRule(NYXFilterRule(name: "r", kind: .regex, pattern: "([")), .invalidRegex)
        XCTAssertEqual(store.addRule(NYXFilterRule(name: "r", pattern: "ok")), .ok)
        XCTAssertEqual(store.prefs.filterRules.count, 1)
    }
}
