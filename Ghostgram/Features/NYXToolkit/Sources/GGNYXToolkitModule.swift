import Foundation
import SwiftUI
import UIKit
import GGCore
import GGSettingsUI
import GGNYXToolkitCore

public enum GGNYXToolkitModule {
    static let section = GGMenuSectionID("nyxToolkit.main")

    public static func register() {
        GGMenuRegistry.register(section: GGMenuSectionDescriptor(id: GGNYXToolkitModule.section, screen: .category(.more), order: 60))
        GGMenuRegistry.register(GGMenuRow(
            id: "nyxToolkit.open",
            section: GGNYXToolkitModule.section,
            order: 100,
            title: { tk("NYX Toolkit", "NYX Toolkit") },
            subtitle: { tk("Event log, message filter rules, Streamer-mode masking tester.", "Журнал событий, правила фильтров, проверка маскировки для стримов.") },
            icon: .system("wrench.and.screwdriver"),
            kind: .action({ menuContext in
                GGNYXToolkitModule.open(menuContext)
            }),
            searchKeywords: { ["log", "журнал", "filter", "фильтр", "streamer", "стример", "mask"] }
        ))
    }

    private static func open(_ menuContext: GGMenuContext) {
        var controller: UIHostingController<NYXToolkitRootView>?
        let root = NYXToolkitRootView(close: { controller?.dismiss(animated: true, completion: nil) })
        let hosting = UIHostingController(rootView: root)
        hosting.modalPresentationStyle = .pageSheet
        controller = hosting
        menuContext.presentNative(hosting)
    }
}

func tk(_ en: String, _ ru: String) -> String {
    return Locale.preferredLanguages.first?.hasPrefix("ru") == true ? ru : en
}
