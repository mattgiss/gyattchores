// swift-tools-version:5.9
import PackageDescription

// The game rules and data model shared by the iOS app. No UI, so it builds and tests with `swift test`.
let package = Package(
    name: "GyattCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "GyattCore", targets: ["GyattCore"])],
    targets: [
        .target(name: "GyattCore"),
        .testTarget(name: "GyattCoreTests", dependencies: ["GyattCore"]),
    ]
)
