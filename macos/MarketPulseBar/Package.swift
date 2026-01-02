// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarketPulseBar",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../../shared/MarketPulseShared")
    ],
    targets: [
        .executableTarget(
            name: "MarketPulseBar",
            dependencies: [
                .product(name: "MarketPulseCore", package: "MarketPulseShared"),
                .product(name: "MarketPulseUI", package: "MarketPulseShared")
            ]
        ),
    ]
)
