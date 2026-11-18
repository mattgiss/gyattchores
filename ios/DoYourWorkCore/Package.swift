// swift-tools-version:5.9
import PackageDescription

// The game rules and data model shared by the iOS app. No UI, so it builds and tests with `swift test`.
let package = Package(
    name: "DoYourWorkCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "DoYourWorkCore", targets: ["DoYourWorkCore"])],
    // The relay's encryption uses CryptoKit on Apple platforms. swift-crypto is the same API for
    // Linux, where CI runs these tests; the iOS app never links it.
    dependencies: [.package(url: "https://github.com/apple/swift-crypto.git", "3.15.0"..<"4.0.0")],
    targets: [
        .target(name: "DoYourWorkCore", dependencies: [
            .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
        ]),
        // Fixtures: backups written by the real apps, so the format can't drift unnoticed.
        .testTarget(name: "DoYourWorkCoreTests", dependencies: ["DoYourWorkCore"], resources: [.copy("Fixtures")]),
    ]
)
