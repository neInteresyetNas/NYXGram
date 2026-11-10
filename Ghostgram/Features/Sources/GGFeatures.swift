import Foundation
import GGSettingsUI
import GGFeaturesShared
import GGGhostMode
import GGAntiDelete
import GGMessages
import GGAppearance
import GGInterface
import GGVoice
import GGCameraMasks
import GGCallsMedia
import GGSecurity
import GGNetworkSpoof
import GGVless
import GGProfileExport
import GGExtras
import GGRegDate
import GGGiftsStudio
import GGNYXToolkit

/// Aggregator of the feature modules, called from `AppDelegate` (see FOUNDATION_SPEC §2):
/// `GGCore.bootstrap` → `GGFeatures.registerAll()` → `GGCore.runGlobalMigrations()` →
/// `GGHookRegistry.freeze()`. Only `register()` calls live here; nobody edits it after wave 1.
public enum GGFeatures {
    public static func registerAll() {
        assert(Thread.isMainThread)
        // The menu skeleton first: features add rows to its sections.
        GGSettingsUI.register()
        GGFeaturesShared.registerForApp()
        GGGhostModeModule.register()
        GGAntiDeleteModule.register()
        GGMessagesModule.register()
        GGAppearanceModule.register()
        GGInterfaceModule.register()
        GGVoiceModule.register()
        // NYXGram: GGCameraMasksModule is not registered (see NYXGRAM_CHANGES.md).
        GGCallsMediaModule.register()
        GGSecurityModule.register()
        // NYXGram: GGNetworkSpoofModule is not registered (see NYXGRAM_CHANGES.md).
        // NYXGram: GGVlessModule is not registered (see NYXGRAM_CHANGES.md).
        GGProfileExportModule.register()
        // W5-SG: Swiftgram-parity features.
        GGExtrasModule.register()
        // W7-RD2: «Дата регистрации».
        // NYXGram: GGRegDateModule is not registered (see NYXGRAM_CHANGES.md).
        // NYXGram: Gifts Studio (read-only catalog/collection, local layouts).
        GGGiftsStudioModule.register()
        // NYXGram: Toolkit (event log, filter rules, streamer masking tester).
        GGNYXToolkitModule.register()
    }
}
