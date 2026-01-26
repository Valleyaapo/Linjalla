// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RT_Bus",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RT_Bus",
            targets: ["RT_Bus"]),
        .library(
            name: "RTBusCore",
            targets: ["RTBusCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.12.1"),
    ],
    targets: [
        .target(
            name: "RTBusCore",
            dependencies: [],
            path: "RT Bus Core"
        ),
        .target(
            name: "RT_Bus",
            dependencies: [
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                "RTBusCore",
            ],
            path: "RT Bus",
            exclude: [
                "RT_BusApp.swift",
                "ContentView.swift",
                "Assets.xcassets",
                "RT Bus 2025-12-30 20-16-49",
                "Settings.bundle",
                "bussit_icon.icon"
            ],
            sources: [
                "Managers/BaseVehicleManager.swift",
                "Managers/BusManager.swift",
                "Managers/TramManager.swift",
                "Managers/StopManager.swift",
                "Managers/TrainManager.swift",
                "Managers/LocationManager.swift",
                "Managers/MapStateManager.swift",
                "Models/BusModel.swift",
                "Models/MapItem.swift",
                "Secrets.swift",
                "Secrets.swift",
                "Theme.swift"
            ],
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "RT_BusTests",
            dependencies: ["RT_Bus", "RTBusCore"],
            path: "RT BusTests"
        ),
    ]
)
