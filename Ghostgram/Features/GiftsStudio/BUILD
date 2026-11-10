load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

# NYXGram Gifts Studio. Two targets:
#
#   GGGiftsStudioCore — pure Swift (Foundation only): models, search/filter/sort, the versioned local
#                       store with backup and corruption handling. No Telegram code, so it is unit-testable.
#   GGGiftsStudio     — the feature: reads the real Telegram gift data, SwiftUI screens, menu row.
#
# Gifts Studio never buys, sends, transfers, converts, withdraws, upgrades or deletes gifts
# (Scripts/check-gifts-forbidden.sh checks the sources for those calls).
swift_library(
    name = "GGGiftsStudioCore",
    module_name = "GGGiftsStudioCore",
    srcs = glob([
        "Core/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "GGGiftsStudio",
    module_name = "GGGiftsStudio",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":GGGiftsStudioCore",
        "//Ghostgram/GGCore:GGCore",
        "//Ghostgram/GGHooks:GGHooks",
        "//Ghostgram/GGSettingsUI:GGSettingsUI",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_test(
    name = "GGGiftsStudioCoreTests",
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":GGGiftsStudioCore",
    ],
)
