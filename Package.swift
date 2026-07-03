// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AirHands",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "AirHandsCore", targets: ["AirHandsCore"]),
        .library(name: "AirHandsVision", targets: ["AirHandsVision"]),
        .executable(name: "airhands-conformance", targets: ["airhands-conformance"]),
    ],
    targets: [
        .target(name: "AirHandsCore"),
        .target(name: "AirHandsVision", dependencies: ["AirHandsCore"]),
        // Shared verification logic: replays the golden vectors exported from
        // the TypeScript reference implementation.
        .target(name: "ConformanceKit", dependencies: ["AirHandsCore"]),
        // CLI runner — works without Xcode (Command Line Tools have no XCTest):
        //   swift run airhands-conformance
        .executableTarget(name: "airhands-conformance", dependencies: ["ConformanceKit"]),
        // Standard `swift test` entry point for environments with Xcode.
        .testTarget(
            name: "AirHandsCoreTests",
            dependencies: ["ConformanceKit"],
            resources: [.copy("Vectors")]
        ),
    ]
)
