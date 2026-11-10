import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import GGGiftsStudioCore

/// Reads the real Telegram gift data (catalog and the user's own collection) and maps it to the pure
/// models of `GGGiftsStudioCore`.
///
/// What this service is allowed to change on Telegram (always after the user confirms in the UI):
///  - show / hide a gift on the profile,
///  - pin / unpin a gift,
///  - the order of the pinned gifts.
/// It deliberately has NO code path for buying, sending, transferring, converting to Stars,
/// withdrawing, upgrading, reselling or deleting gifts. `Scripts/check-gifts-forbidden.sh` enforces that.
final class NYXGiftsService {
    private let context: AccountContext
    private let profileGifts: ProfileGiftsContext
    private let referenceLock = NSLock()
    private var references: [String: StarGiftReference] = [:]

    init(context: AccountContext) {
        self.context = context
        self.profileGifts = ProfileGiftsContext(account: context.account, peerId: context.account.peerId)
    }

    /// Pin limit from Telegram's app config; 6 when the config has none.
    var maxPinned: Int {
        if let value = self.context.currentAppConfiguration.with({ $0 }).data?["stargifts_pinned_to_top_limit"] as? Double {
            return max(1, Int(value))
        }
        return 6
    }

    // MARK: Catalog

    /// Keeps Telegram's gift catalog fresh while the returned signal is subscribed.
    func keepCatalogUpdated() -> Signal<Never, NoError> {
        return self.context.engine.payments.keepStarGiftsUpdated()
    }

    /// Catalog from Telegram's cache.
    func catalog() -> Signal<[NYXGiftItem], NoError> {
        return self.context.engine.payments.cachedStarGifts()
        |> map { gifts -> [NYXGiftItem] in
            guard let gifts = gifts else {
                return []
            }
            var result: [NYXGiftItem] = []
            for (index, gift) in gifts.enumerated() {
                if let item = NYXGiftsService.catalogItem(gift, order: index) {
                    result.append(item)
                }
            }
            return result
        }
    }

    private static func catalogItem(_ gift: StarGift, order: Int) -> NYXGiftItem? {
        switch gift {
        case let .generic(gift):
            let limited = gift.availability != nil
            return NYXGiftItem(
                id: "gift:\(gift.id)",
                title: gift.title ?? "",
                kind: limited ? .limited : .regular,
                priceStars: gift.price,
                remains: gift.availability?.remains,
                total: gift.availability?.total,
                requiresPremium: gift.flags.contains(.requiresPremium),
                isBirthday: gift.flags.contains(.isBirthdayGift),
                thumbnail: gift.file.immediateThumbnailData,
                order: order
            )
        case let .unique(gift):
            return NYXGiftsService.uniqueItem(id: "gift:\(gift.id)", gift: gift, order: order, ownership: nil)
        }
    }

    private static func uniqueItem(id: String, gift: StarGift.UniqueGift, order: Int, ownership: NYXGiftOwnership?) -> NYXGiftItem {
        var names: [String] = []
        var rarity: String?
        var thumbnail: Data?
        for attribute in gift.attributes {
            switch attribute {
            case let .model(name, file, attributeRarity, _):
                names.append(name)
                thumbnail = file.immediateThumbnailData
                rarity = NYXGiftsService.rarityText(attributeRarity)
            case let .pattern(name, _, _):
                names.append(name)
            case let .backdrop(name, _, _, _, _, _, _):
                names.append(name)
            case .originalInfo:
                break
            }
        }
        return NYXGiftItem(
            id: id,
            title: gift.title,
            kind: .unique,
            remains: gift.availability.total - gift.availability.issued,
            total: gift.availability.total,
            number: gift.number,
            rarity: rarity,
            attributes: names,
            thumbnail: thumbnail,
            order: order,
            ownership: ownership
        )
    }

    private static func rarityText(_ rarity: StarGift.UniqueGift.Attribute.Rarity) -> String {
        switch rarity {
        case let .permille(value):
            let percent = Double(value) / 10.0
            return String(format: "%.1f%%", percent)
        case .uncommon:
            return "Uncommon"
        case .rare:
            return "Rare"
        case .epic:
            return "Epic"
        case .legendary:
            return "Legendary"
        }
    }

    // MARK: Own collection

    func collection() -> Signal<[NYXGiftItem], NoError> {
        self.profileGifts.reload()
        return self.profileGifts.state
        |> map { [weak self] state -> [NYXGiftItem] in
            guard let self = self else {
                return []
            }
            return self.items(from: state)
        }
    }

    func loadMore() {
        self.profileGifts.loadMore()
    }

    private func items(from state: ProfileGiftsContext.State) -> [NYXGiftItem] {
        var result: [NYXGiftItem] = []
        var map: [String: StarGiftReference] = [:]
        for (index, entry) in state.gifts.enumerated() {
            guard let reference = entry.reference else {
                // Without a reference Telegram cannot be asked to change this gift; it is not listed as manageable.
                continue
            }
            let key = NYXGiftsService.key(for: reference)
            map[key] = reference
            let ownership = NYXGiftOwnership(
                referenceKey: key,
                savedToProfile: entry.savedToProfile,
                pinnedToTop: entry.pinnedToTop,
                date: entry.date,
                fromName: entry.nameHidden ? nil : entry.fromPeer?.compactDisplayTitle
            )
            switch entry.gift {
            case let .generic(gift):
                result.append(NYXGiftItem(
                    id: "own:\(key)",
                    title: gift.title ?? "",
                    kind: gift.availability != nil ? .limited : .regular,
                    priceStars: gift.price,
                    remains: gift.availability?.remains,
                    total: gift.availability?.total,
                    requiresPremium: gift.flags.contains(.requiresPremium),
                    isBirthday: gift.flags.contains(.isBirthdayGift),
                    thumbnail: gift.file.immediateThumbnailData,
                    order: index,
                    ownership: ownership
                ))
            case let .unique(gift):
                result.append(NYXGiftsService.uniqueItem(id: "own:\(key)", gift: gift, order: index, ownership: ownership))
            }
        }
        self.referenceLock.lock()
        self.references = map
        self.referenceLock.unlock()
        return result
    }

    /// Stable string for a Telegram reference (used for local notes / favorites and to find the reference again).
    static func key(for reference: StarGiftReference) -> String {
        switch reference {
        case let .message(messageId):
            return "msg:\(messageId.peerId.toInt64()):\(messageId.namespace):\(messageId.id)"
        case let .peer(peerId, id):
            return "peer:\(peerId.toInt64()):\(id)"
        case let .slug(slug):
            return "slug:\(slug)"
        }
    }

    private func reference(forKey key: String) -> StarGiftReference? {
        self.referenceLock.lock()
        defer { self.referenceLock.unlock() }
        return self.references[key]
    }

    // MARK: Changes on Telegram (the UI asks the user to confirm before calling these)

    @discardableResult
    func setShownOnProfile(key: String, shown: Bool) -> Bool {
        guard let reference = self.reference(forKey: key) else {
            return false
        }
        self.profileGifts.updateStarGiftAddedToProfile(reference: reference, added: shown)
        return true
    }

    @discardableResult
    func setPinned(key: String, pinned: Bool) -> Bool {
        guard let reference = self.reference(forKey: key) else {
            return false
        }
        self.profileGifts.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: pinned)
        return true
    }

    /// Replaces the order of the pinned gifts. Keys that are no longer known are skipped; the list is
    /// cut to the pin limit. Returns how many were sent.
    @discardableResult
    func applyPinnedOrder(keys: [String]) -> Int {
        var references: [StarGiftReference] = []
        for key in keys {
            if let reference = self.reference(forKey: key) {
                references.append(reference)
            }
        }
        references = Array(references.prefix(self.maxPinned))
        self.profileGifts.updatePinnedToTopStarGifts(references: references)
        return references.count
    }
}
