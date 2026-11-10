import Foundation

public enum NYXStoreIssue: Equatable {
    case restoredFromBackup
    case resetAfterCorruption
}

/// One Codable value in one JSON file: atomic writes, previous good file kept as `.bak`, a damaged file is
/// restored from the backup or set aside as `.corrupt-<time>` (never silently deleted).
public final class NYXJSONFileStore<Value: Codable & Equatable> {
    private let fileURL: URL
    private let lock = NSLock()
    private var value: Value
    public private(set) var loadIssue: NYXStoreIssue?

    public init(fileURL: URL, defaultValue: Value) {
        self.fileURL = fileURL
        self.value = defaultValue
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        self.load(defaultValue)
    }

    public var current: Value {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.value
    }

    /// `normalize` runs after every change (caps, clean-up).
    public func update(normalize: (inout Value) -> Void = { _ in }, _ change: (inout Value) -> Void) {
        self.lock.lock()
        defer { self.lock.unlock() }
        var next = self.value
        change(&next)
        normalize(&next)
        if next != self.value {
            self.value = next
            self.save()
        }
    }

    private var backupURL: URL { return self.fileURL.appendingPathExtension("bak") }

    private func read(_ url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Value.self, from: data)
    }

    private func load(_ defaultValue: Value) {
        let fm = FileManager.default
        if fm.fileExists(atPath: self.fileURL.path) {
            if let main = self.read(self.fileURL) {
                self.value = main
                return
            }
            let stamp = Int(Date().timeIntervalSince1970)
            try? fm.moveItem(at: self.fileURL, to: self.fileURL.appendingPathExtension("corrupt-\(stamp)"))
            if let backup = self.read(self.backupURL) {
                self.value = backup
                self.loadIssue = .restoredFromBackup
                self.save()
            } else {
                self.loadIssue = .resetAfterCorruption
            }
        } else if let backup = self.read(self.backupURL) {
            self.value = backup
            self.loadIssue = .restoredFromBackup
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self.value) else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: self.fileURL.path), self.read(self.fileURL) != nil {
            try? fm.removeItem(at: self.backupURL)
            try? fm.copyItem(at: self.fileURL, to: self.backupURL)
        }
        try? data.write(to: self.fileURL, options: [.atomic])
    }
}
