// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HearthstoneTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HearthstoneTracker", targets: ["HearthstoneTracker"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HearthstoneTracker",
            path: "Sources",
            resources: [
                .copy("Resources/AppIcon.iconset")
            ],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        )
    ]
)
