import Foundation
import SwiftUI
import UIKit
import GGCore
import GGSettingsUI

/// Entry point of Gifts Studio. Adds one action row to the «More» screen of the NYXGram menu; nothing
/// runs until the user opens it.
public enum GGGiftsStudioModule {
    static let section = GGMenuSectionID("giftsStudio.main")

    /// Called once on the main thread from `GGFeatures.registerAll()`, before `GGHookRegistry.freeze()`.
    public static func register() {
        GGMenuRegistry.register(section: GGMenuSectionDescriptor(id: GGGiftsStudioModule.section, screen: .category(.more), order: 50))
        GGMenuRegistry.register(GGMenuRow(
            id: "giftsStudio.open",
            section: GGGiftsStudioModule.section,
            order: 100,
            title: { nyxT("Gifts Studio", "Gifts Studio") },
            subtitle: { nyxT("Catalog, your collection and profile layouts. Never buys or sends gifts.", "Каталог, ваша коллекция и раскладки профиля. Ничего не покупает и не отправляет.") },
            icon: .system("gift"),
            kind: .action({ context in
                GGGiftsStudioModule.open(context)
            }),
            searchKeywords: { ["gifts", "подарки", "collection", "коллекция", "stars"] }
        ))
    }

    private static func open(_ menuContext: GGMenuContext) {
        let model = NYXGiftsViewModel(context: menuContext.context)
        var controller: UIHostingController<NYXGiftsRootView>?
        let root = NYXGiftsRootView(model: model, close: {
            controller?.dismiss(animated: true, completion: nil)
        })
        let hosting = UIHostingController(rootView: root)
        hosting.modalPresentationStyle = .pageSheet
        controller = hosting
        menuContext.presentNative(hosting)
    }
}
