import XCTest
@testable import GGGiftsStudioCore

final class NYXGiftsStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        self.directory = FileManager.default.temporaryDirectory.appendingPathComponent("nyx-gifts-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true, attributes: nil)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: self.directory)
        super.tearDown()
    }

    private var file: URL { return self.directory.appendingPathComponent("prefs.json") }

    func testPersistsAcrossInstances() {
        let store = NYXGiftsStore(fileURL: self.file)
        store.update { $0.favorites = ["a", "b"]; $0.notes["a"] = "hello" }
        let reloaded = NYXGiftsStore(fileURL: self.file)
        XCTAssertEqual(reloaded.current.favorites, ["a", "b"])
        XCTAssertEqual(reloaded.current.notes["a"], "hello")
        XCTAssertNil(reloaded.loadIssue)
    }

    func testSecondSaveCreatesBackup() {
        let store = NYXGiftsStore(fileURL: self.file)
        store.update { $0.favorites = ["a"] }
        store.update { $0.favorites = ["a", "b"] }
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.file.appendingPathExtension("bak").path))
    }

    func testCorruptMainFileRestoresBackup() throws {
        let store = NYXGiftsStore(fileURL: self.file)
        store.update { $0.favorites = ["a"] }
        store.update { $0.favorites = ["a", "b"] }
        try Data("not json".utf8).write(to: self.file)
        let reloaded = NYXGiftsStore(fileURL: self.file)
        XCTAssertEqual(reloaded.loadIssue, .restoredFromBackup)
        XCTAssertEqual(reloaded.current.favorites, ["a"])
    }

    func testCorruptWithoutBackupResetsAndKeepsDamagedFile() throws {
        try Data("garbage".utf8).write(to: self.file)
        let store = NYXGiftsStore(fileURL: self.file)
        XCTAssertEqual(store.loadIssue, .resetAfterCorruption)
        XCTAssertEqual(store.current, NYXGiftsPrefs())
        let names = (try? FileManager.default.contentsOfDirectory(atPath: self.directory.path)) ?? []
        XCTAssertTrue(names.contains(where: { $0.contains("corrupt-") }))
    }

    func testNewerSchemaIsReadOnlyAndFileIsUntouched() throws {
        var newer = NYXGiftsPrefs()
        newer.schemaVersion = NYXGiftsPrefs.currentVersion + 1
        newer.favorites = ["x"]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let original = try encoder.encode(newer)
        try original.write(to: self.file)
        let store = NYXGiftsStore(fileURL: self.file)
        XCTAssertEqual(store.loadIssue, .newerVersionReadOnly)
        store.update { $0.favorites = ["changed"] }
        XCTAssertEqual(try Data(contentsOf: self.file), original)
    }

    func testExportImportRoundTrip() throws {
        let store = NYXGiftsStore(fileURL: self.file)
        store.update { $0.favorites = ["a"]; $0.compositions = [NYXProfileComposition(name: "L", giftKeys: ["a"])] }
        let data = try XCTUnwrap(store.exportData())
        let other = NYXGiftsStore(fileURL: self.directory.appendingPathComponent("other.json"))
        try other.importData(data)
        XCTAssertEqual(other.current.favorites, ["a"])
        XCTAssertEqual(other.current.compositions.first?.name, "L")
    }

    func testImportRejectsGarbageAndNewerVersions() throws {
        let store = NYXGiftsStore(fileURL: self.file)
        XCTAssertThrowsError(try store.importData(Data("nope".utf8))) { XCTAssertEqual($0 as? NYXGiftsImportError, .notValidData) }
        var newer = NYXGiftsPrefs()
        newer.schemaVersion = 99
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(newer)
        XCTAssertThrowsError(try store.importData(data)) { XCTAssertEqual($0 as? NYXGiftsImportError, .newerVersion) }
    }

    func testLimitsAreEnforced() {
        let store = NYXGiftsStore(fileURL: self.file)
        store.update { prefs in
            prefs.notes["a"] = String(repeating: "x", count: NYXGiftsPrefs.maxNoteLength + 50)
            prefs.favorites = ["a", "a", "b"]
            for i in 0..<(NYXGiftsPrefs.maxChangeLog + 20) {
                prefs.changeLog.append(NYXChangeEntry(date: Date(timeIntervalSince1970: Double(i)), text: "\(i)"))
            }
        }
        XCTAssertEqual(store.current.notes["a"]?.count, NYXGiftsPrefs.maxNoteLength)
        XCTAssertEqual(store.current.favorites, ["a", "b"])
        XCTAssertEqual(store.current.changeLog.count, NYXGiftsPrefs.maxChangeLog)
        XCTAssertEqual(store.current.changeLog.last?.text, "\(NYXGiftsPrefs.maxChangeLog + 19)")
    }

    func testActiveCompositionClearedWhenDeleted() {
        let store = NYXGiftsStore(fileURL: self.file)
        let composition = NYXProfileComposition(name: "L")
        store.update { $0.compositions = [composition]; $0.activeCompositionID = composition.id }
        store.update { $0.compositions = [] }
        XCTAssertNil(store.current.activeCompositionID)
    }

    func testResetKeepsBackupOfPreviousData() {
        let store = NYXGiftsStore(fileURL: self.file)
        store.update { $0.favorites = ["a"] }
        store.resetAll()
        XCTAssertTrue(store.current.favorites.isEmpty)
    }
}
