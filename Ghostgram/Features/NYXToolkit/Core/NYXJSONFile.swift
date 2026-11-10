import Foundation

/// One small JSON file with an atomic write, a backup of the previous good version and quarantine of a
/// damaged file (never silently deleted).
public final class NYXJSONFile<Value: Codable & Equatable> {
    private let url: URL
    private let lock = NSLock()
    public private(set) var value: Value
    public private(set) var recovered = false

    public init(url: URL, defaultValue: Value) {
        self.url = url
        self.value = defaultValue
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        if let main = NYXJSONFile.read(url, as: Value.self) {
            self.value = main
        } else if FileManager.default.fileExists(atPath: url.path) {
            self.recovered = true
            let stamp = Int(Date().timeIntervalSince1970)
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("corrupt-\(stamp)"))
            if let backup = NYXJSONFile.read(url.appendingPathExtension("bak"), as: Value.self) {
                self.value = backup
            }
        }
    }

    private static func read<T: Decodable>(_ url: URL, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    @discardableResult
    public func update(_ change: (inout Value) -> Void) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        var next = self.value
        change(&next)
        guard next != self.value else { return true }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(next) else { return false }
        let fm = FileManager.default
        if fm.fileExists(atPath: self.url.path), NYXJSONFile.read(self.url, as: Value.self) != nil {
            let backup = self.url.appendingPathExtension("bak")
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: self.url, to: backup)
        }
        do {
            try data.write(to: self.url, options: [.atomic])
            self.value = next
            return true
        } catch {
            return false
        }
    }
}
