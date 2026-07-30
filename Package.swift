// swift-tools-version:6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "ClipboardX",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ClipboardX", targets: ["ClipboardX"]),
        .library(name: "ClipboardCore", targets: ["ClipboardCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "ClipboardCore",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "ClipboardPlatform",
            dependencies: ["ClipboardCore"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "ClipboardUI",
            dependencies: [
                "ClipboardCore",
                "ClipboardPlatform",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "ClipboardX",
            dependencies: ["ClipboardUI"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ClipboardCoreTests",
            dependencies: ["ClipboardCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ClipboardPlatformTests",
            dependencies: ["ClipboardPlatform"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ClipboardUITests",
            dependencies: ["ClipboardUI"],
            swiftSettings: swiftSettings
        ),
    ]
)
