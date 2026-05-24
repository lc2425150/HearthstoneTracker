// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HearthstoneTracker",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HearthstoneTracker",
            path: "HearthstoneTracker-iOS",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
