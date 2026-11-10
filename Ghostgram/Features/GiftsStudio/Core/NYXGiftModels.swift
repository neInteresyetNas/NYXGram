import Foundation

/// Kinds of gifts as Telegram describes them. Nothing here is invented: a value that Telegram does not
/// provide stays nil and the UI shows nothing for it.
public enum NYXGiftKind: String, Codable, CaseIterable {
    /// Unlimited catalog gift.
    case regular
    /// Limited-supply catalog gift.
    case limited
    /// Collectible (upgraded) gift.
    case unique
}

/// Ownership data of a gift in the user's own collection.
public struct NYXGiftOwnership: Equatable {
    /// Stable string for the Telegram reference of this exact gift (see `NYXGiftsService`).
    public let referenceKey: String
    public let savedToProfile: Bool
    public let pinnedToTop: Bool
    public let date: Int32
    public let fromName: String?

    public init(referenceKey: String, savedToProfile: Bool, pinnedToTop: Bool, date: Int32, fromName: String?) {
        self.referenceKey = referenceKey
        self.savedToProfile = savedToProfile
        self.pinnedToTop = pinnedToTop
        self.date = date
        self.fromName = fromName
    }
}

/// One gift, from the catalog or from the user's collection.
public struct NYXGiftItem: Equatable, Identifiable {
    /// "gift:<id>" for catalog entries, "own:<referenceKey>" for collection entries.
    public let id: String
    public let title: String
    public let kind: NYXGiftKind
    /// Catalog price in Stars, when Telegram gives one.
    public let priceStars: Int64?
    public let remains: Int32?
    public let total: Int32?
    /// Serial number of a collectible.
    public let number: Int32?
    /// Rarity text exactly as derived from Telegram's data (permille or Telegram's own rarity name).
    public let rarity: String?
    /// Names of the collectible's model, pattern and backdrop, when present.
    public let attributes: [String]
    public let requiresPremium: Bool
    public let isBirthday: Bool
    /// Tiny blurred preview that ships with the gift file; the real image or animation is not loaded here.
    public let thumbnail: Data?
    /// Position in the source list (the order Telegram returned it in).
    public let order: Int
    public let ownership: NYXGiftOwnership?

    public init(id: String, title: String, kind: NYXGiftKind, priceStars: Int64? = nil, remains: Int32? = nil, total: Int32? = nil, number: Int32? = nil, rarity: String? = nil, attributes: [String] = [], requiresPremium: Bool = false, isBirthday: Bool = false, thumbnail: Data? = nil, order: Int, ownership: NYXGiftOwnership? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.priceStars = priceStars
        self.remains = remains
        self.total = total
        self.number = number
        self.rarity = rarity
        self.attributes = attributes
        self.requiresPremium = requiresPremium
        self.isBirthday = isBirthday
        self.thumbnail = thumbnail
        self.order = order
        self.ownership = ownership
    }

    /// Key used for local favorites, notes and compositions. For collection entries it is the reference
    /// key (it identifies the exact gift); for catalog entries it is the catalog id.
    public var storageKey: String {
        return self.ownership?.referenceKey ?? self.id
    }
}

public enum NYXGiftSort: String, Codable, CaseIterable {
    case newest
    case priceLow
    case priceHigh
    case name
    /// Smaller total supply first (supply is the only scarcity measure Telegram provides for every gift).
    case scarcest
}

public enum NYXVisibilityFilter: String, Codable, CaseIterable {
    case all
    case shown
    case hidden
}

public struct NYXGiftFilter: Codable, Equatable {
    public var search: String
    /// Empty = all kinds.
    public var kinds: Set<NYXGiftKind>
    public var onlyFavorites: Bool
    public var onlyPinned: Bool
    public var visibility: NYXVisibilityFilter

    public init(search: String = "", kinds: Set<NYXGiftKind> = [], onlyFavorites: Bool = false, onlyPinned: Bool = false, visibility: NYXVisibilityFilter = .all) {
        self.search = search
        self.kinds = kinds
        self.onlyFavorites = onlyFavorites
        self.onlyPinned = onlyPinned
        self.visibility = visibility
    }

    public var isDefault: Bool {
        return self == NYXGiftFilter()
    }
}
