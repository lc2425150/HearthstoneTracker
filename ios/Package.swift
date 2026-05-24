// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HearthstoneTracker",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "HearthstoneTracker",
            targets: ["HearthstoneTracker"]
        )
    ],
    targets: [
        .target(
            name: "HearthstoneTracker",
            path: "HearthstoneTracker-iOS",
            exclude: [],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
