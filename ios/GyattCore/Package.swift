// swift-tools-version: 5.9
import PackageDescription

// GyattCore — the game rules, with no UI and no Apple-only frameworks.
// It builds and tests on Linux too (`swift test`), which is how CI checks that
// the Swift port still matches the web app's engine.
let package = Package(
    name: "GyattCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "GyattCore", targets: ["GyattCore"]),
    ],
    targets: [
        .target(name: "GyattCore"),
        .testTarget(
            name: "GyattCoreTests",
            dependencies: ["GyattCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
