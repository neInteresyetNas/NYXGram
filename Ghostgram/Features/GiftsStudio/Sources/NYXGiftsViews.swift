import Foundation
import SwiftUI
import UIKit
import GGGiftsStudioCore

private let nyxViolet = Color(red: 0.55, green: 0.36, blue: 0.96)
private let nyxBackground = Color(red: 0.05, green: 0.04, blue: 0.09)

private extension NYXProfileStyle {
    var title: String {
        switch self {
        case .classic: return nyxT("Classic", "Классика")
        case .minimal: return nyxT("Minimal", "Минимал")
        case .premium: return nyxT("Premium", "Премиум")
        case .collector: return nyxT("Collector", "Коллекционер")
        case .midnight: return nyxT("Midnight", "Полночь")
        case .nyxPurple: return "NYX Purple"
        }
    }
    var cardFill: Color {
        switch self {
        case .classic: return Color(white: 0.16)
        case .minimal: return Color(white: 0.10)
        case .premium: return Color(red: 0.30, green: 0.23, blue: 0.08)
        case .collector: return Color(red: 0.10, green: 0.24, blue: 0.22)
        case .midnight: return Color(red: 0.05, green: 0.08, blue: 0.20)
        case .nyxPurple: return Color(red: 0.24, green: 0.14, blue: 0.45)
        }
    }
    var accent: Color {
        switch self {
        case .premium: return Color(red: 1.0, green: 0.82, blue: 0.35)
        case .collector: return Color(red: 0.35, green: 0.9, blue: 0.75)
        case .midnight: return Color(red: 0.45, green: 0.6, blue: 1.0)
        default: return nyxViolet
        }
    }
}

private extension NYXGiftKind {
    var title: String {
        switch self {
        case .regular: return nyxT("Regular", "Обычный")
        case .limited: return nyxT("Limited", "Лимитированный")
        case .unique: return nyxT("Collectible", "Коллекционный")
        }
    }
}

private extension NYXGiftSort {
    var title: String {
        switch self {
        case .newest: return nyxT("Newest", "Новые")
        case .priceLow: return nyxT("Price ↑", "Цена ↑")
        case .priceHigh: return nyxT("Price ↓", "Цена ↓")
        case .name: return nyxT("Name", "Название")
        case .scarcest: return nyxT("Scarcest", "Самые редкие")
        }
    }
}

struct NYXShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: [self.url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// "Real" Telegram data is shown as is; everything local is labelled as local.
struct NYXGiftsRootView: View {
    @ObservedObject var model: NYXGiftsViewModel
    let close: () -> Void
    @State private var tab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: self.$tab) {
                    Text(nyxT("Catalog", "Каталог")).tag(0)
                    Text(nyxT("Collection", "Коллекция")).tag(1)
                    Text(nyxT("Layout", "Раскладка")).tag(2)
                    Text(nyxT("Data", "Данные")).tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                if let message = self.model.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .onTapGesture { self.model.message = nil }
                }
                Group {
                    switch self.tab {
                    case 0: NYXGiftListView(model: self.model, ownCollection: false)
                    case 1: NYXGiftListView(model: self.model, ownCollection: true)
                    case 2: NYXLayoutView(model: self.model)
                    default: NYXDataView(model: self.model)
                    }
                }
            }
            .background(nyxBackground.ignoresSafeArea())
            .navigationTitle("Gifts Studio")
            .navigationBarItems(trailing: Button(nyxT("Close", "Закрыть"), action: self.close))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(nyxViolet)
        .preferredColorScheme(.dark)
    }
}

struct NYXGiftRow: View {
    let item: NYXGiftItem
    let favorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(nyxViolet.opacity(0.25))
                Image(systemName: "gift.fill").foregroundColor(nyxViolet)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(self.item.title.isEmpty ? nyxT("Gift", "Подарок") : self.item.title).font(.body)
                    if let number = self.item.number { Text("#\(number)").font(.footnote).foregroundColor(.secondary) }
                    if self.favorite { Image(systemName: "star.fill").font(.footnote).foregroundColor(.yellow) }
                }
                Text(self.detail).font(.footnote).foregroundColor(.secondary)
            }
            Spacer()
            if let own = self.item.ownership {
                VStack(alignment: .trailing, spacing: 2) {
                    if own.pinnedToTop { Image(systemName: "pin.fill").foregroundColor(nyxViolet) }
                    if !own.savedToProfile { Image(systemName: "eye.slash").foregroundColor(.secondary) }
                }
            }
        }
    }

    private var detail: String {
        var parts: [String] = [self.item.kind.title]
        if let price = self.item.priceStars { parts.append("\(price) ★") }
        if let total = self.item.total, let remains = self.item.remains { parts.append("\(remains)/\(total)") }
        if let rarity = self.item.rarity { parts.append(rarity) }
        if self.item.requiresPremium { parts.append("Premium") }
        return parts.joined(separator: " · ")
    }
}

enum NYXPendingAction: Identifiable {
    case show(NYXGiftItem, Bool)
    case pin(NYXGiftItem, Bool)
    var id: String {
        switch self {
        case let .show(item, value): return "show-\(item.id)-\(value)"
        case let .pin(item, value): return "pin-\(item.id)-\(value)"
        }
    }
}

struct NYXGiftListView: View {
    @ObservedObject var model: NYXGiftsViewModel
    let ownCollection: Bool
    @State private var selected: NYXGiftItem?

    private var filter: NYXGiftFilter { self.ownCollection ? self.model.prefs.collectionFilter : self.model.prefs.catalogFilter }
    private var sort: NYXGiftSort { self.ownCollection ? self.model.prefs.collectionSort : self.model.prefs.catalogSort }

    private func setFilter(_ f: NYXGiftFilter) {
        let own = self.ownCollection
        self.model.update { if own { $0.collectionFilter = f } else { $0.catalogFilter = f } }
    }

    private func setSort(_ s: NYXGiftSort) {
        let own = self.ownCollection
        self.model.update { if own { $0.collectionSort = s } else { $0.catalogSort = s } }
    }

    private var items: [NYXGiftItem] {
        let source = self.ownCollection ? self.model.collection : self.model.catalog
        return NYXGiftQuery.apply(source, filter: self.filter, sort: self.sort, favorites: Set(self.model.prefs.favorites))
    }

    var body: some View {
        List {
            Section {
                TextField(nyxT("Search", "Поиск"), text: Binding(get: { self.filter.search }, set: { value in
                    var f = self.filter; f.search = value; self.setFilter(f)
                }))
                Picker(nyxT("Sort", "Сортировка"), selection: Binding(get: { self.sort }, set: { self.setSort($0) })) {
                    ForEach(NYXGiftSort.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Toggle(nyxT("Only favorites", "Только избранное"), isOn: Binding(get: { self.filter.onlyFavorites }, set: { value in
                    var f = self.filter; f.onlyFavorites = value; self.setFilter(f)
                }))
                if self.ownCollection {
                    Toggle(nyxT("Only pinned", "Только закреплённые"), isOn: Binding(get: { self.filter.onlyPinned }, set: { value in
                        var f = self.filter; f.onlyPinned = value; self.setFilter(f)
                    }))
                    Picker(nyxT("Profile", "Профиль"), selection: Binding(get: { self.filter.visibility }, set: { value in
                        var f = self.filter; f.visibility = value; self.setFilter(f)
                    })) {
                        Text(nyxT("All", "Все")).tag(NYXVisibilityFilter.all)
                        Text(nyxT("Shown", "Показаны")).tag(NYXVisibilityFilter.shown)
                        Text(nyxT("Hidden", "Скрыты")).tag(NYXVisibilityFilter.hidden)
                    }
                }
                if !self.filter.isDefault {
                    Button(nyxT("Reset filters", "Сбросить фильтры")) { self.setFilter(NYXGiftFilter()) }
                }
            }
            Section(footer: self.footer) {
                if self.items.isEmpty {
                    Text(self.ownCollection && !self.model.isCollectionLoaded ? nyxT("Loading…", "Загрузка…") : nyxT("Nothing found.", "Ничего не найдено."))
                        .foregroundColor(.secondary)
                }
                ForEach(self.items) { item in
                    Button(action: { self.selected = item }) {
                        NYXGiftRow(item: item, favorite: self.model.isFavorite(item))
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .sheet(item: self.$selected) { item in
            NYXGiftDetailView(model: self.model, item: item, ownCollection: self.ownCollection, close: { self.selected = nil })
        }
    }

    private var footer: some View {
        Text(self.ownCollection
             ? nyxT("Your real gifts from Telegram. Showing, hiding and pinning change your real profile after you confirm.", "Ваши настоящие подарки из Telegram. Показ, скрытие и закрепление меняют реальный профиль после подтверждения.")
             : nyxT("Catalog from Telegram. This screen only shows it: Gifts Studio never buys or sends gifts.", "Каталог из Telegram. Этот экран только показывает его: Gifts Studio ничего не покупает и не отправляет."))
    }
}

struct NYXGiftDetailView: View {
    @ObservedObject var model: NYXGiftsViewModel
    let item: NYXGiftItem
    let ownCollection: Bool
    let close: () -> Void
    @State private var note = ""
    @State private var pending: NYXPendingAction?
    @State private var compareTarget: NYXGiftItem?

    var body: some View {
        NavigationView {
            List {
                Section {
                    NYXGiftRow(item: self.item, favorite: self.model.isFavorite(self.item))
                    if !self.item.attributes.isEmpty {
                        Text(self.item.attributes.joined(separator: " · ")).font(.footnote).foregroundColor(.secondary)
                    }
                    if let own = self.item.ownership, let from = own.fromName {
                        Text(nyxT("From: ", "От: ") + from).font(.footnote).foregroundColor(.secondary)
                    }
                }
                Section(header: Text(nyxT("Local (only on this device)", "Локально (только на этом устройстве)"))) {
                    Button(self.model.isFavorite(self.item) ? nyxT("Remove from favorites", "Убрать из избранного") : nyxT("Add to favorites", "В избранное")) {
                        self.model.toggleFavorite(self.item)
                    }
                    TextField(nyxT("Private note", "Личная заметка"), text: self.$note)
                        .onChange(of: self.note) { value in self.model.setNote(value, for: self.item) }
                }
                if let own = self.item.ownership {
                    Section(header: Text(nyxT("On Telegram (asks to confirm)", "В Telegram (с подтверждением)"))) {
                        Button(own.savedToProfile ? nyxT("Hide from profile", "Скрыть из профиля") : nyxT("Show on profile", "Показать в профиле")) {
                            self.pending = .show(self.item, !own.savedToProfile)
                        }
                        Button(own.pinnedToTop ? nyxT("Unpin", "Открепить") : nyxT("Pin to top", "Закрепить")) {
                            self.pending = .pin(self.item, !own.pinnedToTop)
                        }
                    }
                }
                Section(header: Text(nyxT("Compare with", "Сравнить с"))) {
                    ForEach(self.compareCandidates.prefix(20)) { other in
                        Button(other.title) { self.compareTarget = other }
                    }
                    if let other = self.compareTarget {
                        ForEach(Array(self.model.compare(self.item, other).enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.0).foregroundColor(.secondary)
                                Spacer()
                                Text("\(row.1)  |  \(row.2)")
                            }.font(.footnote)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(self.item.title.isEmpty ? nyxT("Gift", "Подарок") : self.item.title)
            .navigationBarItems(trailing: Button(nyxT("Done", "Готово"), action: self.close))
            .onAppear { self.note = self.model.note(for: self.item) }
            .alert(item: self.$pending) { action in
                switch action {
                case let .show(item, shown):
                    return Alert(
                        title: Text(shown ? nyxT("Show on your profile?", "Показать в профиле?") : nyxT("Hide from your profile?", "Скрыть из профиля?")),
                        message: Text(nyxT("This changes your real Telegram profile.", "Это изменит ваш реальный профиль в Telegram.")),
                        primaryButton: .default(Text(nyxT("Confirm", "Подтвердить"))) { self.model.setShown(item, shown: shown) },
                        secondaryButton: .cancel()
                    )
                case let .pin(item, pinned):
                    return Alert(
                        title: Text(pinned ? nyxT("Pin this gift?", "Закрепить подарок?") : nyxT("Unpin this gift?", "Открепить подарок?")),
                        message: Text(nyxT("This changes your real Telegram profile. Pin limit: ", "Это изменит ваш реальный профиль. Лимит закрепов: ") + "\(self.model.service.maxPinned)"),
                        primaryButton: .default(Text(nyxT("Confirm", "Подтвердить"))) { self.model.setPinned(item, pinned: pinned) },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var compareCandidates: [NYXGiftItem] {
        let source = self.ownCollection ? self.model.collection : self.model.catalog
        return source.filter { $0.id != self.item.id }
    }
}

struct NYXLayoutView: View {
    @ObservedObject var model: NYXGiftsViewModel
    @State private var newName = ""
    @State private var showApply = false
    @State private var showPicker = false
    @State private var appliedCount: Int?

    var body: some View {
        List {
            Section(footer: Text(nyxT("A local preview of how your gifts could look. It is NOT published to Telegram. Only “Apply pinned order” changes your real profile, and only after you confirm.", "Локальный предпросмотр. Он НЕ публикуется в Telegram. Только «Применить порядок закрепов» меняет реальный профиль и только после подтверждения."))) {
                ForEach(self.model.prefs.compositions) { composition in
                    Button(action: { self.model.update { $0.activeCompositionID = composition.id } }) {
                        HStack {
                            Text(composition.name)
                            Spacer()
                            if composition.id == self.model.activeComposition?.id { Image(systemName: "checkmark") }
                        }
                    }
                }
                HStack {
                    TextField(nyxT("New layout name", "Название раскладки"), text: self.$newName)
                    Button(nyxT("Add", "Добавить")) { self.model.addComposition(name: self.newName); self.newName = "" }
                }
            }
            if let composition = self.model.activeComposition {
                Section(header: Text(nyxT("Preview (local)", "Предпросмотр (локально)"))) {
                    NYXPreviewGrid(model: self.model, composition: composition)
                }
                Section(header: Text(nyxT("Style", "Стиль"))) {
                    Picker(nyxT("Style", "Стиль"), selection: Binding(get: { composition.style }, set: { value in self.model.editActive { $0.style = value } })) {
                        ForEach(NYXProfileStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Stepper(nyxT("Columns: ", "Колонок: ") + "\(composition.columns)", value: Binding(get: { composition.columns }, set: { value in self.model.editActive { $0.columns = min(max(value, 2), 4) } }), in: 2...4)
                    Stepper(nyxT("Max gifts: ", "Максимум: ") + "\(composition.maxItems)", value: Binding(get: { composition.maxItems }, set: { value in self.model.editActive { $0.maxItems = min(max(value, 1), 50) } }), in: 1...50)
                    Picker(nyxT("Card size", "Размер карточек"), selection: Binding(get: { composition.cardSize }, set: { value in self.model.editActive { $0.cardSize = value } })) {
                        Text("S").tag(NYXCardSize.small); Text("M").tag(NYXCardSize.medium); Text("L").tag(NYXCardSize.large)
                    }.pickerStyle(SegmentedPickerStyle())
                    Toggle(nyxT("Show titles", "Показывать названия"), isOn: Binding(get: { composition.showTitles }, set: { value in self.model.editActive { $0.showTitles = value } }))
                    Toggle(nyxT("Show rarity", "Показывать редкость"), isOn: Binding(get: { composition.showRarity }, set: { value in self.model.editActive { $0.showRarity = value } }))
                }
                Section(header: Text(nyxT("Gifts (drag to reorder)", "Подарки (перетащите для порядка)"))) {
                    ForEach(composition.giftKeys, id: \.self) { key in
                        HStack {
                            Text(self.model.item(forKey: key)?.title ?? key)
                            Spacer()
                            Button(action: { self.model.editActive { $0.primaryKey = key } }) {
                                Image(systemName: composition.primaryKey == key ? "star.fill" : "star")
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .onMove { source, destination in
                        guard let from = source.first else { return }
                        self.model.editActive { $0.giftKeys = NYXListMove.move($0.giftKeys, from: from, to: destination > from ? destination - 1 : destination) }
                    }
                    .onDelete { offsets in
                        self.model.editActive { composition in
                            for index in offsets.sorted(by: >) where index < composition.giftKeys.count { composition.giftKeys.remove(at: index) }
                        }
                    }
                    Button(nyxT("Add gifts…", "Добавить подарки…")) { self.showPicker = true }
                    EditButton()
                }
                Section(footer: Text(nyxT("Sends the first pinned-capable gifts of this layout, in order, as your real pinned gifts.", "Отправляет первые подарки этой раскладки как реальные закрепы в этом порядке."))) {
                    Button(nyxT("Apply pinned order to Telegram…", "Применить порядок закрепов в Telegram…")) { self.showApply = true }
                    Button(nyxT("Delete this layout", "Удалить раскладку")) { self.model.deleteActiveComposition() }.foregroundColor(.red)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .sheet(isPresented: self.$showPicker) { NYXGiftPicker(model: self.model, close: { self.showPicker = false }) }
        .alert(isPresented: self.$showApply) {
            Alert(
                title: Text(nyxT("Change your real pinned gifts?", "Изменить реальные закрепы?")),
                message: Text(nyxT("This updates the pinned gifts on your Telegram profile.", "Это обновит закреплённые подарки в вашем профиле Telegram.")),
                primaryButton: .default(Text(nyxT("Apply", "Применить"))) { self.appliedCount = self.model.applyActiveOrderToTelegram() },
                secondaryButton: .cancel()
            )
        }
    }
}

struct NYXPreviewGrid: View {
    @ObservedObject var model: NYXGiftsViewModel
    let composition: NYXProfileComposition

    private var side: CGFloat {
        switch self.composition.cardSize {
        case .small: return 56
        case .medium: return 76
        case .large: return 100
        }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: self.composition.columns)
        VStack(alignment: .leading, spacing: 6) {
            Text(nyxT("Local preview — not published to Telegram", "Локальный предпросмотр — не опубликовано в Telegram"))
                .font(.caption).foregroundColor(.orange)
            if self.composition.visibleKeys.isEmpty {
                Text(nyxT("Add gifts to see the preview.", "Добавьте подарки для предпросмотра.")).foregroundColor(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(self.composition.visibleKeys, id: \.self) { key in
                    let item = self.model.item(forKey: key)
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(self.composition.style.cardFill)
                            Image(systemName: key == self.composition.primaryKey ? "gift.circle.fill" : "gift.fill")
                                .foregroundColor(self.composition.style.accent)
                        }
                        .frame(height: self.side)
                        if self.composition.showTitles, let item = item {
                            Text(item.title).font(.caption2).lineLimit(1)
                        }
                        if self.composition.showRarity, let rarity = item?.rarity {
                            Text(rarity).font(.caption2).foregroundColor(self.composition.style.accent)
                        }
                    }
                }
            }
        }
    }
}

struct NYXGiftPicker: View {
    @ObservedObject var model: NYXGiftsViewModel
    let close: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(self.model.collection) { item in
                    let key = item.storageKey
                    let included = self.model.activeComposition?.giftKeys.contains(key) ?? false
                    Button(action: {
                        self.model.editActive { composition in
                            if let index = composition.giftKeys.firstIndex(of: key) { composition.giftKeys.remove(at: index) } else { composition.giftKeys.append(key) }
                        }
                    }) {
                        HStack { NYXGiftRow(item: item, favorite: false); Image(systemName: included ? "checkmark.circle.fill" : "circle") }
                    }
                }
            }
            .navigationTitle(nyxT("Add gifts", "Добавить подарки"))
            .navigationBarItems(trailing: Button(nyxT("Done", "Готово"), action: self.close))
        }
    }
}

struct NYXDataView: View {
    @ObservedObject var model: NYXGiftsViewModel
    @State private var exportURL: URL?
    @State private var confirmReset = false

    var body: some View {
        List {
            Section(header: Text(nyxT("Backup", "Резервная копия")), footer: Text(nyxT("Settings, notes, favorites and layouts are stored only on this device. Export/import never touches your Telegram profile.", "Настройки, заметки, избранное и раскладки хранятся только на этом устройстве. Экспорт/импорт не затрагивает профиль Telegram."))) {
                Button(nyxT("Export settings", "Экспорт настроек")) { self.exportURL = self.model.exportFileURL() }
                Button(nyxT("Import from clipboard", "Импорт из буфера")) { self.model.importFromClipboard() }
                Button(nyxT("Reset local data", "Сбросить локальные данные")) { self.confirmReset = true }.foregroundColor(.red)
            }
            Section(header: Text(nyxT("Local change history", "История локальных изменений"))) {
                if self.model.prefs.changeLog.isEmpty { Text(nyxT("Empty", "Пусто")).foregroundColor(.secondary) }
                ForEach(Array(self.model.prefs.changeLog.reversed().enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading) {
                        Text(entry.text).font(.footnote)
                        Text(entry.date, style: .date).font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .sheet(item: Binding(get: { self.exportURL.map { NYXURLBox(url: $0) } }, set: { _ in self.exportURL = nil })) { box in
            NYXShareSheet(url: box.url)
        }
        .alert(isPresented: self.$confirmReset) {
            Alert(
                title: Text(nyxT("Reset local Gifts Studio data?", "Сбросить локальные данные?")),
                message: Text(nyxT("Favorites, notes and layouts on this device will be removed. Your Telegram gifts are not affected.", "Избранное, заметки и раскладки на этом устройстве будут удалены. Подарки в Telegram не затрагиваются.")),
                primaryButton: .destructive(Text(nyxT("Reset", "Сбросить"))) { self.model.resetLocalData() },
                secondaryButton: .cancel()
            )
        }
    }
}

struct NYXURLBox: Identifiable {
    let url: URL
    var id: String { return self.url.absoluteString }
}
