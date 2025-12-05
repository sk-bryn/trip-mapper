// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TripVisualizer",
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
            path: "Sources/TripVisualizer",
            resources: [
                .copy("Resources/map-template.html")
            ]
        ),
        .testTarget(
            name: "TripVisualizerTests",
            dependencies: ["TripVisualizer"],
            path: "Tests/TripVisualizerTests"
        )
    ]
)
