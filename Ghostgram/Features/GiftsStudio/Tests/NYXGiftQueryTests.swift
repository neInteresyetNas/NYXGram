import XCTest
@testable import GGGiftsStudioCore

final class NYXGiftQueryTests: XCTestCase {
    private func own(_ key: String, title: String, order: Int, saved: Bool = true, pinned: Bool = false, date: Int32 = 0, price: Int64? = nil, total: Int32? = nil, kind: NYXGiftKind = .regular) -> NYXGiftItem {
        return NYXGiftItem(id: "own:\(key)", title: title, kind: kind, priceStars: price, total: total, order: order, ownership: NYXGiftOwnership(referenceKey: key, savedToProfile: saved, pinnedToTop: pinned, date: date, fromName: nil))
    }

    func testSearchIsCaseInsensitiveAndMatchesAttributes() {
        let a = NYXGiftItem(id: "gift:1", title: "Plush Pepe", kind: .unique, number: 7, attributes: ["Neon"], order: 0)
        let b = NYXGiftItem(id: "gift:2", title: "Heart", kind: .regular, order: 1)
        var filter = NYXGiftFilter()
        filter.search = "pepe"
        XCTAssertEqual(NYXGiftQuery.apply([a, b], filter: filter, sort: .name, favorites: []).map { $0.id }, ["gift:1"])
        filter.search = "NEON"
        XCTAssertEqual(NYXGiftQuery.apply([a, b], filter: filter, sort: .name, favorites: []).count, 1)
        filter.search = "#7"
        XCTAssertEqual(NYXGiftQuery.apply([a, b], filter: filter, sort: .name, favorites: []).count, 1)
    }

    func testVisibilityAndPinnedFilters() {
        let shown = own("a", title: "A", order: 0)
        let hidden = own("b", title: "B", order: 1, saved: false)
        let pinned = own("c", title: "C", order: 2, pinned: true)
        var filter = NYXGiftFilter()
        filter.visibility = .hidden
        XCTAssertEqual(NYXGiftQuery.apply([shown, hidden, pinned], filter: filter, sort: .name, favorites: []).map { $0.title }, ["B"])
        filter.visibility = .shown
        XCTAssertEqual(NYXGiftQuery.apply([shown, hidden, pinned], filter: filter, sort: .name, favorites: []).count, 2)
        filter = NYXGiftFilter(onlyPinned: true)
        XCTAssertEqual(NYXGiftQuery.apply([shown, hidden, pinned], filter: filter, sort: .name, favorites: []).map { $0.title }, ["C"])
    }

    func testFavoritesUseStorageKey() {
        let a = own("k1", title: "A", order: 0)
        let b = own("k2", title: "B", order: 1)
        let filter = NYXGiftFilter(onlyFavorites: true)
        XCTAssertEqual(NYXGiftQuery.apply([a, b], filter: filter, sort: .name, favorites: ["k2"]).map { $0.title }, ["B"])
    }

    func testNilValuesSortLastInBothDirections() {
        let a = own("a", title: "A", order: 0, price: nil)
        let b = own("b", title: "B", order: 1, price: 10)
        let c = own("c", title: "C", order: 2, price: 5)
        XCTAssertEqual(NYXGiftQuery.sorted([a, b, c], by: .priceLow).map { $0.title }, ["C", "B", "A"])
        XCTAssertEqual(NYXGiftQuery.sorted([a, b, c], by: .priceHigh).map { $0.title }, ["B", "C", "A"])
    }

    func testNewestAndScarcestAreDeterministic() {
        let a = own("a", title: "A", order: 0, date: 5, total: 100)
        let b = own("b", title: "B", order: 1, date: 5, total: 10)
        let c = own("c", title: "C", order: 2, date: 9, total: nil)
        XCTAssertEqual(NYXGiftQuery.sorted([a, b, c], by: .newest).map { $0.title }, ["C", "A", "B"])
        XCTAssertEqual(NYXGiftQuery.sorted([a, b, c], by: .scarcest).map { $0.title }, ["B", "A", "C"])
    }

    func testMove() {
        XCTAssertEqual(NYXListMove.move([1, 2, 3, 4], from: 0, to: 2), [2, 3, 1, 4])
        XCTAssertEqual(NYXListMove.move([1, 2, 3, 4], from: 3, to: 0), [4, 1, 2, 3])
        XCTAssertEqual(NYXListMove.move([1, 2, 3], from: 5, to: 0), [1, 2, 3])
        XCTAssertEqual(NYXListMove.move([1, 2, 3], from: 1, to: 1), [1, 2, 3])
    }

    func testCompositionVisibleKeysPutPrimaryFirstAndRespectMax() {
        let composition = NYXProfileComposition(name: "x", giftKeys: ["a", "b", "c", "d"], primaryKey: "c", maxItems: 3)
        XCTAssertEqual(composition.visibleKeys, ["c", "a", "b"])
    }

    func testCompositionClampsColumnsAndMax() {
        let composition = NYXProfileComposition(name: "x", columns: 99, maxItems: 0)
        XCTAssertEqual(composition.columns, 4)
        XCTAssertEqual(composition.maxItems, 1)
    }
}
