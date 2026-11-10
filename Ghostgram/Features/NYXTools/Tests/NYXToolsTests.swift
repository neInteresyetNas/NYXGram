import XCTest
@testable import GGNYXToolsCore

final class NYXToolsTests: XCTestCase {
    func testPlainAndCaseRules() {
        var rule = NYXFilterRule(name: "r", pattern: "Promo")
        XCTAssertTrue(NYXFilterEngine.matches(rule, in: "big promo today"))
        rule.caseSensitive = true
        XCTAssertFalse(NYXFilterEngine.matches(rule, in: "big promo today"))
    }

    func testRegexValidationAndMatch() {
        var rule = NYXFilterRule(name: "r", pattern: "(", isRegex: true)
        XCTAssertEqual(NYXFilterEngine.validate(rule), "invalid regex")
        XCTAssertFalse(NYXFilterEngine.matches(rule, in: "("))
        rule.pattern = "\\d{3}-\\d{2}"
        XCTAssertNil(NYXFilterEngine.validate(rule))
        XCTAssertTrue(NYXFilterEngine.matches(rule, in: "code 123-45"))
    }

    func testDisabledAndEmptyNeverMatch() {
        XCTAssertFalse(NYXFilterEngine.matches(NYXFilterRule(name: "r", pattern: "x", enabled: false), in: "x"))
        XCTAssertFalse(NYXFilterEngine.matches(NYXFilterRule(name: "r", pattern: ""), in: "x"))
    }

    func testDecisionPriority() {
        let rules = [NYXFilterRule(name: "a", pattern: "spam", action: .mute), NYXFilterRule(name: "b", pattern: "spam", action: .hide), NYXFilterRule(name: "c", pattern: "zzz", action: .highlight)]
        XCTAssertEqual(NYXFilterEngine.decision(rules, text: "spam"), .hide)
        XCTAssertNil(NYXFilterEngine.decision(rules, text: "clean"))
    }

    func testRedactor() {
        var options = NYXRedactionOptions()
        XCTAssertTrue(NYXRedactor.redact("call +375 29 123-45-67 now", options: options).contains("+•••"))
        XCTAssertFalse(NYXRedactor.redact("mail me a@b.com", options: options).contains("a@b.com"))
        // 4111 1111 1111 1111 passes Luhn, 4111 1111 1111 1112 does not.
        XCTAssertTrue(NYXRedactor.redact("card 4111 1111 1111 1111", options: options).hasSuffix("1111"))
        XCTAssertFalse(NYXRedactor.redact("card 4111 1111 1111 1111", options: options).contains("4111 1111"))
        options.links = true
        XCTAssertTrue(NYXRedactor.redact("see https://example.com/x", options: options).contains("[link hidden]"))
        XCTAssertEqual(NYXRedactor.redact("plain text", options: options), "plain text")
    }

    func testLuhn() {
        XCTAssertTrue(NYXRedactor.luhn("4111111111111111"))
        XCTAssertFalse(NYXRedactor.luhn("4111111111111112"))
    }

    func testTemplateKeepsUnknownPlaceholders() {
        let out = NYXTemplateRenderer.render("Hi {name}, {unknown}", now: Date(timeIntervalSince1970: 0), name: "Max")
        XCTAssertEqual(out, "Hi Max, {unknown}")
    }

    func testStoreCapsAndBackup() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("nyx-tools-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("tools.json")
        let store = NYXToolsStore(fileURL: file)
        for i in 0..<(NYXToolsPrefs.maxEvents + 10) { store.log(.system, "e\(i)", now: Date(timeIntervalSince1970: Double(i))) }
        XCTAssertEqual(store.current.events.count, NYXToolsPrefs.maxEvents)
        XCTAssertEqual(store.current.events.last?.text, "e\(NYXToolsPrefs.maxEvents + 9)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.appendingPathExtension("bak").path))
        try Data("bad".utf8).write(to: file)
        let reloaded = NYXToolsStore(fileURL: file)
        XCTAssertEqual(reloaded.store.loadIssue, .restoredFromBackup)
        XCTAssertFalse(reloaded.current.events.isEmpty)
    }
}
