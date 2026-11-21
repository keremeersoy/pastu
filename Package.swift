// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pastu",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PastuCore", targets: ["PastuCore"]),
        .executable(name: "Pastu", targets: ["Pastu"]),
    ],
    targets: [
        // UI-independent logic: capture, privacy filter, storage, search.
        .target(name: "PastuCore"),
        // Menu bar app shell (SwiftUI/AppKit).
        .executableTarget(name: "Pastu", dependencies: ["PastuCore"]),
        .testTarget(name: "PastuCoreTests", dependencies: ["PastuCore"]),
        // Tests for the app shell (panel, key handling); run in-process with real AppKit windows.
        .testTarget(name: "PastuTests", dependencies: ["Pastu", "PastuCore"]),
    ]
)
