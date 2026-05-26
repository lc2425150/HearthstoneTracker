// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HearthstoneTracker",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "HearthstoneTracker", targets: ["HearthstoneTracker"])
    ],
    targets: [
        .target(
            name: "HearthstoneTracker",
            dependencies: [],
            path: "HearthstoneTracker-iOS",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        )
    ]
)
