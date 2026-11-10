load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")

# NYXGram Toolkit: local event log, message-filter rules, Streamer-mode text redaction.
# Core is Foundation-only (unit-testable); the feature target adds the SwiftUI screens and the menu row.
swift_library(
    name = "GGNYXToolkitCore",
    module_name = "GGNYXToolkitCore",
    srcs = glob(["Core/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "GGNYXToolkit",
    module_name = "GGNYXToolkit",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        ":GGNYXToolkitCore",
        "//Ghostgram/GGCore:GGCore",
        "//Ghostgram/GGSettingsUI:GGSettingsUI",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
    ],
    visibility = ["//visibility:public"],
)

swift_test(
    name = "GGNYXToolkitCoreTests",
    srcs = glob(["Tests/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [":GGNYXToolkitCore"],
)
