import Foundation

public enum NYXProfileStyle: String, Codable, CaseIterable {
    case classic, minimal, premium, collector, midnight, nyxPurple
}

public enum NYXCardSize: String, Codable, CaseIterable {
    case small, medium, large
}

/// A local arrangement of gifts. It is only ever a LOCAL preview unless the user explicitly applies the
/// pinned order to Telegram (see the "Apply to Telegram" step in the UI).
public struct NYXProfileComposition: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    /// `NYXGiftItem.storageKey` values, in display order.
    public var giftKeys: [String]
    public var primaryKey: String?
    public var style: NYXProfileStyle
    public var columns: Int
    public var cardSize: NYXCardSize
    public var showTitles: Bool
    public var showRarity: Bool
    public var maxItems: Int

    public init(id: UUID = UUID(), name: String, giftKeys: [String] = [], primaryKey: String? = nil, style: NYXProfileStyle = .nyxPurple, columns: Int = 3, cardSize: NYXCardSize = .medium, showTitles: Bool = true, showRarity: Bool = false, maxItems: Int = 12) {
        self.id = id
        self.name = name
        self.giftKeys = giftKeys
        self.primaryKey = primaryKey
        self.style = style
        self.columns = min(max(columns, 2), 4)
        self.cardSize = cardSize
        self.showTitles = showTitles
        self.showRarity = showRarity
        self.maxItems = min(max(maxItems, 1), 50)
    }

    /// The keys that are actually shown, honouring `maxItems`, with the primary gift first.
    public var visibleKeys: [String] {
        var keys = self.giftKeys
        if let primary = self.primaryKey, let index = keys.firstIndex(of: primary), index != 0 {
            keys.remove(at: index)
            keys.insert(primary, at: 0)
        }
        return Array(keys.prefix(self.maxItems))
    }
}

public struct NYXChangeEntry: Codable, Equatable {
    public var date: Date
    public var text: String
    public init(date: Date, text: String) {
        self.date = date
        self.text = text
    }
}

/// Everything Gifts Studio keeps locally. Versioned so it can be migrated.
public struct NYXGiftsPrefs: Codable, Equatable {
    public static let currentVersion = 1
    public static let maxNotes = 5000
    public static let maxNoteLength = 2000
    public static let maxCompositions = 50
    public static let maxChangeLog = 200

    public var schemaVersion: Int = NYXGiftsPrefs.currentVersion
    public var favorites: [String] = []
    public var notes: [String: String] = [:]
    public var compositions: [NYXProfileComposition] = []
    public var activeCompositionID: UUID?
    public var catalogFilter: NYXGiftFilter = NYXGiftFilter()
    public var catalogSort: NYXGiftSort = .name
    public var collectionFilter: NYXGiftFilter = NYXGiftFilter()
    public var collectionSort: NYXGiftSort = .newest
    public var changeLog: [NYXChangeEntry] = []

    public init() {}

    /// Drops anything that breaks the limits (used after import and on load).
    mutating func normalize() {
        self.favorites = Array(NSOrderedSet(array: self.favorites).array as? [String] ?? self.favorites)
        if self.notes.count > NYXGiftsPrefs.maxNotes {
            let keep = self.notes.keys.sorted().prefix(NYXGiftsPrefs.maxNotes)
            self.notes = self.notes.filter { keep.contains($0.key) }
        }
        for (key, value) in self.notes where value.count > NYXGiftsPrefs.maxNoteLength {
            self.notes[key] = String(value.prefix(NYXGiftsPrefs.maxNoteLength))
        }
        self.notes = self.notes.filter { !$0.value.isEmpty }
        if self.compositions.count > NYXGiftsPrefs.maxCompositions {
            self.compositions = Array(self.compositions.prefix(NYXGiftsPrefs.maxCompositions))
        }
        if let active = self.activeCompositionID, !self.compositions.contains(where: { $0.id == active }) {
            self.activeCompositionID = nil
        }
        if self.changeLog.count > NYXGiftsPrefs.maxChangeLog {
            self.changeLog = Array(self.changeLog.suffix(NYXGiftsPrefs.maxChangeLog))
        }
    }
}
