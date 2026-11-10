import Foundation
import SwiftUI
import GGNYXToolkitCore

private let violet = Color(red: 0.55, green: 0.36, blue: 0.96)

final class NYXToolkitModel: ObservableObject {
    private let store = NYXToolkitStore.shared
    private let log = NYXEventLog.shared
    @Published var rules: [NYXFilterRule]
    @Published var redaction: NYXRedactionOptions
    @Published var events: [NYXEvent]

    init() {
        self.rules = store.prefs.filterRules
        self.redaction = store.prefs.redaction
        self.events = log.query()
        if store.wasRecovered || log.wasRecovered {
            log.record(.warning, source: "Toolkit", "A damaged data file was set aside and a backup or defaults were used.")
            self.events = log.query()
        }
    }

    func addRule(_ rule: NYXFilterRule) -> NYXFilterValidation {
        let result = store.addRule(rule)
        if result == .ok { log.record(source: "Filters", "Rule added: \(rule.name)") }
        refresh()
        return result
    }

    func updateRule(_ rule: NYXFilterRule) {
        store.update { prefs in
            if let i = prefs.filterRules.firstIndex(where: { $0.id == rule.id }) { prefs.filterRules[i] = rule }
        }
        refresh()
    }

    func deleteRules(at offsets: IndexSet) {
        let ids = offsets.compactMap { $0 < rules.count ? rules[$0].id : nil }
        store.update { $0.filterRules.removeAll { ids.contains($0.id) } }
        log.record(source: "Filters", "Rule deleted")
        refresh()
    }

    func setRedaction(_ options: NYXRedactionOptions) {
        store.update { $0.redaction = options }
        refresh()
    }

    func clearLog() {
        log.clear()
        refresh()
    }

    func refresh() {
        rules = store.prefs.filterRules
        redaction = store.prefs.redaction
        events = log.query()
    }
}

struct NYXToolkitRootView: View {
    let close: () -> Void
    @StateObject private var model = NYXToolkitModel()
    @State private var tab = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text(tk("Overview", "Обзор")).tag(0)
                    Text(tk("Events", "События")).tag(1)
                    Text(tk("Filters", "Фильтры")).tag(2)
                    Text(tk("Streamer", "Стример")).tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(16)
                switch tab {
                case 0: NYXOverviewView(model: model)
                case 1: NYXEventsView(model: model)
                case 2: NYXFiltersView(model: model)
                default: NYXStreamerView(model: model)
                }
            }
            .navigationTitle("NYX Toolkit")
            .navigationBarItems(trailing: Button(tk("Close", "Закрыть"), action: close))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(violet)
        .preferredColorScheme(.dark)
    }
}

struct NYXOverviewView: View {
    @ObservedObject var model: NYXToolkitModel
    var body: some View {
        List {
            Section(footer: Text(tk("Everything here is stored only on this device.", "Всё хранится только на этом устройстве."))) {
                row(tk("Events recorded", "Записано событий"), "\(model.events.count)")
                row(tk("Warnings", "Предупреждения"), "\(model.events.filter { $0.severity == .warning }.count)")
                row(tk("Filter rules", "Правил фильтров"), "\(model.rules.count) (\(model.rules.filter { $0.enabled }.count) " + tk("on", "вкл") + ")")
            }
            Section(header: Text(tk("Status", "Статус"))) {
                Text(tk("Filter rules and masking are tested here on text you type. They are not yet applied to your chats.", "Правила фильтров и маскировка проверяются здесь на введённом тексте. К вашим чатам они пока не применяются."))
                    .font(.footnote).foregroundColor(.orange)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundColor(.secondary) }
    }
}

struct NYXEventsView: View {
    @ObservedObject var model: NYXToolkitModel
    @State private var search = ""
    @State private var confirmClear = false
    private var shown: [NYXEvent] {
        let needle = search.lowercased()
        return needle.isEmpty ? model.events : model.events.filter { $0.text.lowercased().contains(needle) || $0.source.lowercased().contains(needle) }
    }
    var body: some View {
        List {
            Section {
                TextField(tk("Search", "Поиск"), text: $search)
                Button(tk("Clear log", "Очистить журнал")) { confirmClear = true }.foregroundColor(.red)
            }
            Section {
                if shown.isEmpty { Text(tk("No events.", "Событий нет.")).foregroundColor(.secondary) }
                ForEach(Array(shown.enumerated()), id: \.offset) { _, event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.text).font(.footnote).foregroundColor(event.severity == .warning ? .orange : .primary)
                        Text("\(event.source) · \(event.date, style: .date) \(event.date, style: .time)").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .alert(isPresented: $confirmClear) {
            Alert(title: Text(tk("Clear the event log?", "Очистить журнал?")), primaryButton: .destructive(Text(tk("Clear", "Очистить"))) { model.clearLog() }, secondaryButton: .cancel())
        }
    }
}

struct NYXFiltersView: View {
    @ObservedObject var model: NYXToolkitModel
    @State private var name = ""
    @State private var pattern = ""
    @State private var kind = NYXFilterKind.keyword
    @State private var action = NYXFilterAction.hide
    @State private var error: String?
    @State private var testText = ""

    var body: some View {
        List {
            Section(header: Text(tk("New rule", "Новое правило"))) {
                TextField(tk("Name", "Название"), text: $name)
                TextField(tk("Text or pattern", "Текст или шаблон"), text: $pattern).autocapitalization(.none).disableAutocorrection(true)
                Picker(tk("Match", "Совпадение"), selection: $kind) {
                    Text(tk("Contains", "Содержит")).tag(NYXFilterKind.keyword)
                    Text(tk("Whole word", "Слово целиком")).tag(NYXFilterKind.wholeWord)
                    Text("Regex").tag(NYXFilterKind.regex)
                }.pickerStyle(SegmentedPickerStyle())
                Picker(tk("Action", "Действие"), selection: $action) {
                    Text(tk("Hide", "Скрыть")).tag(NYXFilterAction.hide)
                    Text(tk("Mute", "Без звука")).tag(NYXFilterAction.mute)
                    Text(tk("Highlight", "Выделить")).tag(NYXFilterAction.highlight)
                }.pickerStyle(SegmentedPickerStyle())
                if let error = error { Text(error).font(.footnote).foregroundColor(.red) }
                Button(tk("Add rule", "Добавить правило")) {
                    let rule = NYXFilterRule(name: name.isEmpty ? pattern : name, kind: kind, pattern: pattern, action: action)
                    switch model.addRule(rule) {
                    case .ok: error = nil; name = ""; pattern = ""
                    case .emptyPattern: error = tk("Enter a text or pattern.", "Введите текст или шаблон.")
                    case .tooLong: error = tk("Too long or too many rules.", "Слишком длинно или слишком много правил.")
                    case .invalidRegex: error = tk("The regular expression is not valid.", "Регулярное выражение некорректно.")
                    }
                }
            }
            Section(header: Text(tk("Rules", "Правила"))) {
                if model.rules.isEmpty { Text(tk("No rules yet.", "Правил пока нет.")).foregroundColor(.secondary) }
                ForEach(model.rules) { rule in
                    Toggle(isOn: Binding(get: { rule.enabled }, set: { value in var r = rule; r.enabled = value; model.updateRule(r) })) {
                        VStack(alignment: .leading) {
                            Text(rule.name)
                            Text("\(rule.kind.rawValue) · \(rule.action.rawValue) · \(rule.pattern)").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }
                .onDelete { model.deleteRules(at: $0) }
            }
            Section(header: Text(tk("Test", "Проверка")), footer: Text(testResult)) {
                TextField(tk("Type a message to test", "Введите сообщение для проверки"), text: $testText)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private var testResult: String {
        if testText.isEmpty { return "" }
        if let hit = NYXMessageFilter.decide(model.rules, text: testText) {
            return tk("Would apply: ", "Сработает: ") + hit.action.rawValue + " (" + hit.rule.name + ")"
        }
        return tk("No rule matches.", "Ни одно правило не сработало.")
    }
}

struct NYXStreamerView: View {
    @ObservedObject var model: NYXToolkitModel
    @State private var sample = "Call +49 151 2345 6789, mail me at name@example.com, card 4242 4242 4242 4242, https://t.me/example, @example_user"

    var body: some View {
        List {
            Section(header: Text(tk("What to mask", "Что скрывать"))) {
                toggle(tk("Phone numbers", "Номера телефонов"), \.phones)
                toggle(tk("Emails", "Email"), \.emails)
                toggle(tk("Links", "Ссылки"), \.links)
                toggle(tk("Card numbers", "Номера карт"), \.cardNumbers)
                toggle(tk("@usernames", "@юзернеймы"), \.usernames)
            }
            Section(header: Text(tk("Try it", "Попробуйте")), footer: Text(tk("Masking is shown here on sample text. It is not yet applied to chats, and may also mask date-like number groups.", "Маскировка показана на примере. В чатах она пока не применяется и может скрывать числа, похожие на даты."))) {
                TextField(tk("Sample text", "Пример текста"), text: $sample)
                Text(NYXRedactor.redact(sample, options: model.redaction)).font(.footnote)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private func toggle(_ title: String, _ path: WritableKeyPath<NYXRedactionOptions, Bool>) -> some View {
        Toggle(title, isOn: Binding(get: { model.redaction[keyPath: path] }, set: { value in
            var options = model.redaction
            options[keyPath: path] = value
            model.setRedaction(options)
        }))
    }
}
