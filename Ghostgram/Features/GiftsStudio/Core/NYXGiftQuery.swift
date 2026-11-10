import Foundation

/// Pure search / filter / sort over a list of gifts. No Telegram types, fully unit-testable.
public enum NYXGiftQuery {
    public static func apply(_ items: [NYXGiftItem], filter: NYXGiftFilter, sort: NYXGiftSort, favorites: Set<String>) -> [NYXGiftItem] {
        let needle = filter.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = items.filter { item in
            if !filter.kinds.isEmpty && !filter.kinds.contains(item.kind) {
                return false
            }
            if filter.onlyFavorites && !favorites.contains(item.storageKey) {
                return false
            }
            if filter.onlyPinned && item.ownership?.pinnedToTop != true {
                return false
            }
            switch filter.visibility {
            case .all:
                break
            case .shown:
                if item.ownership?.savedToProfile != true { return false }
            case .hidden:
                guard let ownership = item.ownership, !ownership.savedToProfile else { return false }
            }
            if !needle.isEmpty && !NYXGiftQuery.searchText(item).contains(needle) {
                return false
            }
            return true
        }
        return NYXGiftQuery.sorted(filtered, by: sort)
    }

    static func searchText(_ item: NYXGiftItem) -> String {
        var parts = [item.title]
        parts.append(contentsOf: item.attributes)
        if let number = item.number {
            parts.append("#\(number)")
        }
        if let rarity = item.rarity {
            parts.append(rarity)
        }
        return parts.joined(separator: " ").lowercased()
    }

    public static func sorted(_ items: [NYXGiftItem], by sort: NYXGiftSort) -> [NYXGiftItem] {
        // Every comparison falls back to the source order so the result is deterministic.
        switch sort {
        case .newest:
            return items.sorted { a, b in
                let da = a.ownership?.date ?? Int32.min
                let db = b.ownership?.date ?? Int32.min
                if da != db { return da > db }
                return a.order < b.order
            }
        case .priceLow:
            return items.sorted { a, b in
                NYXGiftQuery.optionalLess(a.priceStars, b.priceStars, a.order, b.order, ascending: true)
            }
        case .priceHigh:
            return items.sorted { a, b in
                NYXGiftQuery.optionalLess(a.priceStars, b.priceStars, a.order, b.order, ascending: false)
            }
        case .name:
            return items.sorted { a, b in
                let c = a.title.localizedCaseInsensitiveCompare(b.title)
                if c != .orderedSame { return c == .orderedAscending }
                return a.order < b.order
            }
        case .scarcest:
            return items.sorted { a, b in
                NYXGiftQuery.optionalLess(a.total.map(Int64.init), b.total.map(Int64.init), a.order, b.order, ascending: true)
            }
        }
    }

    /// Values that are nil always go last, in both directions.
    private static func optionalLess(_ a: Int64?, _ b: Int64?, _ ao: Int, _ bo: Int, ascending: Bool) -> Bool {
        switch (a, b) {
        case let (x?, y?):
            if x != y { return ascending ? x < y : x > y }
            return ao < bo
        case (nil, nil):
            return ao < bo
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }
}

public enum NYXListMove {
    /// Moves one element; out-of-range indices leave the list unchanged. `to` is the final index.
    public static func move<T>(_ list: [T], from: Int, to: Int) -> [T] {
        guard from != to, list.indices.contains(from), list.indices.contains(to) else {
            return list
        }
        var result = list
        let element = result.remove(at: from)
        result.insert(element, at: to)
        return result
    }
}
