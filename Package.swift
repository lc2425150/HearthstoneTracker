// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "HearthstoneTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "HearthstoneTracker", path: "Sources")
    ]
)
