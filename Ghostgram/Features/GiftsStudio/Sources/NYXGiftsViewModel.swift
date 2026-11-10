import Foundation
import SwiftUI
import SwiftSignalKit
import TelegramCore
import AccountContext
import GGGiftsStudioCore

/// Small helper: Russian when the device language is Russian, English otherwise.
func nyxT(_ en: String, _ ru: String) -> String {
    return Locale.preferredLanguages.first?.hasPrefix("ru") == true ? ru : en
}

final class NYXGiftsViewModel: ObservableObject {
    @Published var catalog: [NYXGiftItem] = []
    @Published var collection: [NYXGiftItem] = []
    @Published var prefs: NYXGiftsPrefs
    @Published var isCollectionLoaded = false
    @Published var message: String?

    let service: NYXGiftsService
    private let store: NYXGiftsStore
    private let disposables = DisposableSet()

    init(context: AccountContext, store: NYXGiftsStore = NYXGiftsStore.shared) {
        self.service = NYXGiftsService(context: context)
        self.store = store
        self.prefs = store.current
        if let issue = store.loadIssue {
            switch issue {
            case .restoredFromBackup:
                self.message = nyxT("Settings file was damaged; the backup was restored.", "Файл настроек повреждён, восстановлена резервная копия.")
            case .resetAfterCorruption:
                self.message = nyxT("Settings file was damaged and set aside; defaults are used.", "Файл настроек повреждён и отложен, используются значения по умолчанию.")
            case .newerVersionReadOnly:
                self.message = nyxT("Settings were saved by a newer version; changes are not saved.", "Настройки сохранены более новой версией; изменения не сохраняются.")
            }
        }
        self.disposables.add(self.service.keepCatalogUpdated().start())
        self.disposables.add((self.service.catalog() |> deliverOnMainQueue).start(next: { [weak self] items in
            self?.catalog = items
        }))
        self.disposables.add((self.service.collection() |> deliverOnMainQueue).start(next: { [weak self] items in
            self?.collection = items
            self?.isCollectionLoaded = true
        }))
    }

    deinit {
        self.disposables.dispose()
    }

    // MARK: Local prefs

    func update(_ change: @escaping (inout NYXGiftsPrefs) -> Void) {
        self.store.update(change)
        self.prefs = self.store.current
    }

    func log(_ text: String) {
        self.store.log(text)
        self.prefs = self.store.current
    }

    func isFavorite(_ item: NYXGiftItem) -> Bool {
        return self.prefs.favorites.contains(item.storageKey)
    }

    func toggleFavorite(_ item: NYXGiftItem) {
        let key = item.storageKey
        self.update { prefs in
            if let index = prefs.favorites.firstIndex(of: key) {
                prefs.favorites.remove(at: index)
            } else {
                prefs.favorites.append(key)
            }
        }
    }

    func note(for item: NYXGiftItem) -> String {
        return self.prefs.notes[item.storageKey] ?? ""
    }

    func setNote(_ text: String, for item: NYXGiftItem) {
        let key = item.storageKey
        self.update { $0.notes[key] = text }
    }

    // MARK: Changes on Telegram (the view confirms first)

    func setShown(_ item: NYXGiftItem, shown: Bool) {
        guard let key = item.ownership?.referenceKey, self.service.setShownOnProfile(key: key, shown: shown) else {
            return
        }
        self.log((shown ? "Shown on profile: " : "Hidden from profile: ") + item.title)
    }

    func setPinned(_ item: NYXGiftItem, pinned: Bool) {
        guard let key = item.ownership?.referenceKey, self.service.setPinned(key: key, pinned: pinned) else {
            return
        }
        self.log((pinned ? "Pinned: " : "Unpinned: ") + item.title)
    }

    func applyActiveOrderToTelegram() -> Int {
        guard let composition = self.activeComposition else {
            return 0
        }
        let ownKeys = composition.visibleKeys.filter { $0.hasPrefix("msg:") || $0.hasPrefix("peer:") || $0.hasPrefix("slug:") }
        let sent = self.service.applyPinnedOrder(keys: ownKeys)
        self.log("Applied pinned order to Telegram (\(sent) gifts) from \"\(composition.name)\"")
        return sent
    }

    // MARK: Compositions

    var activeComposition: NYXProfileComposition? {
        if let id = self.prefs.activeCompositionID, let found = self.prefs.compositions.first(where: { $0.id == id }) {
            return found
        }
        return self.prefs.compositions.first
    }

    func addComposition(name: String) {
        let composition = NYXProfileComposition(name: name.isEmpty ? nyxT("My layout", "Моя раскладка") : name)
        self.update { prefs in
            prefs.compositions.append(composition)
            prefs.activeCompositionID = composition.id
        }
        self.log("Created layout \"\(composition.name)\"")
    }

    func deleteActiveComposition() {
        guard let composition = self.activeComposition else {
            return
        }
        self.update { prefs in
            prefs.compositions.removeAll { $0.id == composition.id }
            prefs.activeCompositionID = prefs.compositions.first?.id
        }
        self.log("Deleted layout \"\(composition.name)\"")
    }

    func editActive(_ change: @escaping (inout NYXProfileComposition) -> Void) {
        guard let composition = self.activeComposition else {
            return
        }
        self.update { prefs in
            if let index = prefs.compositions.firstIndex(where: { $0.id == composition.id }) {
                change(&prefs.compositions[index])
            }
        }
    }

    func item(forKey key: String) -> NYXGiftItem? {
        return self.collection.first(where: { $0.storageKey == key }) ?? self.catalog.first(where: { $0.storageKey == key })
    }

    // MARK: Backup

    func exportFileURL() -> URL? {
        guard let data = self.store.exportData() else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nyx-gifts-studio.json")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }

    func importFromClipboard() {
        guard let text = UIPasteboard.general.string, let data = text.data(using: .utf8) else {
            self.message = nyxT("The clipboard has no settings text.", "В буфере нет текста настроек.")
            return
        }
        do {
            try self.store.importData(data)
            self.prefs = self.store.current
            self.log("Imported settings")
            self.message = nyxT("Settings imported.", "Настройки импортированы.")
        } catch NYXGiftsImportError.newerVersion {
            self.message = nyxT("These settings come from a newer NYXGram.", "Эти настройки из более новой версии NYXGram.")
        } catch {
            self.message = nyxT("Could not import: the text is not valid Gifts Studio settings.", "Не удалось импортировать: это не настройки Gifts Studio.")
        }
    }

    func resetLocalData() {
        self.store.resetAll()
        self.prefs = self.store.current
    }

    // MARK: Compare

    /// Differences between two gifts as plain lines (only facts Telegram provided).
    func compare(_ a: NYXGiftItem, _ b: NYXGiftItem) -> [(String, String, String)] {
        func s(_ v: Int64?) -> String { return v.map { String($0) } ?? "—" }
        func i(_ v: Int32?) -> String { return v.map { String($0) } ?? "—" }
        return [
            (nyxT("Type", "Тип"), a.kind.rawValue, b.kind.rawValue),
            (nyxT("Price (Stars)", "Цена (Stars)"), s(a.priceStars), s(b.priceStars)),
            (nyxT("Supply", "Тираж"), i(a.total), i(b.total)),
            (nyxT("Remaining", "Осталось"), i(a.remains), i(b.remains)),
            (nyxT("Number", "Номер"), i(a.number), i(b.number)),
            (nyxT("Rarity", "Редкость"), a.rarity ?? "—", b.rarity ?? "—")
        ]
    }
}
