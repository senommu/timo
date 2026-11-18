// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Timo",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "timo",
            dependencies: ["ExtensionResourceBridge"],
            path: "Sources/Timo",
            resources: [.copy("EaselFonts"), .copy("WelcomeAssets"), .copy("SpaceEmoji"), .copy("MaxAssets")],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedLibrary("sqlite3"),
                .linkedLibrary("z"),
            ]
        ),
        .target(name: "ExtensionResourceBridge", path: "Sources/ExtensionResourceBridge",
                publicHeadersPath: "include", linkerSettings: [.linkedFramework("WebKit")]),
        // A separate libSystem-only process owns revision leases in native tests.
        .executableTarget(name: "NativeLeaseHolder", path: "Tests/NativeLeaseHolder"),
        // Only the XCTest bundle links this early, process-local AppKit setup.
        .target(
            name: "NativeTestHostBootstrap",
            path: "Tests/NativeTestHostBootstrap",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(name: "TimoTests", dependencies: ["timo", "NativeTestHostBootstrap"])
    ]
)
