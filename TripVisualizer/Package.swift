// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TripVisualizer",
    // Note: platforms is only used on Apple platforms. Linux ignores this.
    // macOS 12+ required for async/await URLSession APIs.
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "tripvisualizer",
            targets: ["TripVisualizer"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "TripVisualizer",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/TripVisualizer"
        ),
        .testTarget(
            name: "TripVisualizerTests",
            dependencies: ["TripVisualizer"],
            path: "Tests/TripVisualizerTests"
        )
    ]
)
