import Foundation

public enum NYXGiftsStoreIssue: Equatable {
    /// The main file could not be read; the backup was used.
    case restoredFromBackup
    /// Neither file could be read; the damaged file was set aside and defaults are in use.
    case resetAfterCorruption
    /// The file was written by a newer NYXGram. It is left untouched and changes are kept in memory only.
    case newerVersionReadOnly
}

public enum NYXGiftsImportError: Error, Equatable {
    case notValidData
    case newerVersion
    case writeFailed
}

/// Local persistence for Gifts Studio: one JSON file, written atomically, with a backup of the previous
/// good version. Corrupted data never crashes the app and never silently erases the user's settings:
/// the damaged file is kept next to the new one.
public final class NYXGiftsStore {
    public static let shared = NYXGiftsStore(fileURL: NYXGiftsStore.defaultURL())

    private let fileURL: URL
    private let lock = NSLock()
    private var prefs: NYXGiftsPrefs
    private var readOnly = false
    public private(set) var loadIssue: NYXGiftsStoreIssue?

    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NYXGram", isDirectory: true)
        return base.appendingPathComponent("gifts-studio.json")
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.prefs = NYXGiftsPrefs()
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        self.load()
    }

    private var backupURL: URL {
        return self.fileURL.appendingPathExtension("bak")
    }

    // MARK: Access

    public var current: NYXGiftsPrefs {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.prefs
    }

    public func update(_ change: (inout NYXGiftsPrefs) -> Void) {
        self.lock.lock()
        var next = self.prefs
        change(&next)
        next.schemaVersion = NYXGiftsPrefs.currentVersion
        next.normalize()
        let changed = next != self.prefs
        self.prefs = next
        if changed {
            self.saveLocked()
        }
        self.lock.unlock()
    }

    /// Appends a line to the local change history ("what I changed in my gift layout").
    public func log(_ text: String, now: Date = Date()) {
        self.update { $0.changeLog.append(NYXChangeEntry(date: now, text: text)) }
    }

    /// Back to defaults. The previous file stays as the backup.
    public func resetAll() {
        self.update { $0 = NYXGiftsPrefs() }
    }

    // MARK: Export / import

    public func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self.current)
    }

    /// Replaces the local settings with the imported ones after validating them.
    public func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard data.count <= 5_000_000, var imported = try? decoder.decode(NYXGiftsPrefs.self, from: data) else {
            throw NYXGiftsImportError.notValidData
        }
        if imported.schemaVersion > NYXGiftsPrefs.currentVersion {
            throw NYXGiftsImportError.newerVersion
        }
        imported.schemaVersion = NYXGiftsPrefs.currentVersion
        imported.normalize()
        self.lock.lock()
        defer { self.lock.unlock() }
        if self.readOnly {
            throw NYXGiftsImportError.writeFailed
        }
        self.prefs = imported
        if !self.saveLocked() {
            throw NYXGiftsImportError.writeFailed
        }
    }

    // MARK: Disk

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func read(_ url: URL) -> NYXGiftsPrefs? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? self.decoder().decode(NYXGiftsPrefs.self, from: data)
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: self.fileURL.path) else {
            if fm.fileExists(atPath: self.backupURL.path), var backup = self.read(self.backupURL) {
                backup.normalize()
                self.prefs = backup
                self.loadIssue = .restoredFromBackup
            }
            return
        }
        if var main = self.read(self.fileURL) {
            if main.schemaVersion > NYXGiftsPrefs.currentVersion {
                self.readOnly = true
                self.loadIssue = .newerVersionReadOnly
            }
            main.normalize()
            self.prefs = main
            return
        }
        if var backup = self.read(self.backupURL) {
            backup.normalize()
            self.prefs = backup
            self.loadIssue = .restoredFromBackup
            self.setAsideCorruptFile()
            self.saveLocked()
            return
        }
        self.loadIssue = .resetAfterCorruption
        self.setAsideCorruptFile()
    }

    private func setAsideCorruptFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = self.fileURL.appendingPathExtension("corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: self.fileURL, to: target)
    }

    @discardableResult
    private func saveLocked() -> Bool {
        guard !self.readOnly else {
            return false
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self.prefs) else {
            return false
        }
        let fm = FileManager.default
        // Keep the previous good file as the backup before replacing it.
        if fm.fileExists(atPath: self.fileURL.path), self.read(self.fileURL) != nil {
            try? fm.removeItem(at: self.backupURL)
            try? fm.copyItem(at: self.fileURL, to: self.backupURL)
        }
        do {
            try data.write(to: self.fileURL, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
