// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HearthstoneTracker-iOS",
    platforms: [
        .iOS("17.0")
    ],
    targets: [
        .target(
            name: "HearthstoneTracker-iOS",
            path: "HearthstoneTracker-iOS",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
