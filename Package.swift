// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "macOSDefaultApps",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "DefaultAppsCore", targets: ["DefaultAppsCore"]),
        .executable(name: "mda", targets: ["mda"]),
        .executable(name: "macOSDefaultApps", targets: ["MacOSDefaultAppsApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "DefaultAppsCore", resources: [.copy("Resources/catalog.json")]),
        .executableTarget(
            name: "mda",
            dependencies: [
                "DefaultAppsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "MacOSDefaultAppsApp",
            dependencies: ["DefaultAppsCore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "DefaultAppsTestSupport",
            dependencies: ["DefaultAppsCore"],
            path: "Tests/DefaultAppsTestSupport"
        ),
        .testTarget(
            name: "DefaultAppsCoreTests",
            dependencies: ["DefaultAppsCore", "DefaultAppsTestSupport"]
        ),
        .testTarget(name: "MDATests", dependencies: ["mda"]),
        .testTarget(
            name: "MacOSDefaultAppsAppTests",
            dependencies: ["MacOSDefaultAppsApp", "DefaultAppsTestSupport"]
        ),
    ]
)
