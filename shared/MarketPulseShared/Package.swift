// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MarketPulseShared",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "MarketPulseCore", targets: ["MarketPulseCore"]),
        .library(name: "MarketPulseUI", targets: ["MarketPulseUI"])
    ],
    targets: [
        .target(name: "MarketPulseCore"),
        .target(name: "MarketPulseUI", dependencies: ["MarketPulseCore"])
    ]
)
