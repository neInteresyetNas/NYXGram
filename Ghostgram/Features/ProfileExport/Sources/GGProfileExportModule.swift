import Foundation
import SwiftSignalKit
import GGCore

/// Entry point of the GGProfileExport feature module (W4-1): the GCONNECT nick badge, fake gifts,
/// chat export.
public enum GGProfileExportModule {
    private static var fakeGiftsDisposable: Disposable?

    /// Declares settings, menu rows, hook handlers and migrations. Called once on the main
    /// thread from `GGFeatures.registerAll()`, before `GGHookRegistry.freeze()`.
    public static func register() {
        assert(Thread.isMainThread)
        GGNickBadgeSettings.declare()
        GGFakeGiftsSettings.declare()
        GGLocalStars.declare()
        GGChatExportSettings.declare()
        GGFakeGiftsLegacy.registerMigrations()

        // Nick badge: slots, the network side (off until the user turns badges on), menu.
        // NYXGram: nick badges (third-party server, paid) are not registered.

        // Fake gifts: the profile's list, the gift screen's menu, the store per account.
        // NYXGram: fake gifts and local stars are not registered (they show data that is not real).
        // Local stars: the Stars balance shown on this device (same tab, own section).

        // Chat export: entry points; temporary trees of old jobs are removed off the main thread.
        GGChatExportMenu.register()
        GGChatExportManager.shared.removeStaleJobs()
    }
}
