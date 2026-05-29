// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MileOne",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)  // macOS added so `swift test` can run on the Mac host
    ],
    products: [
        .library(
            name: "MileOne",
            targets: ["MileOne"]
        ),
    ],
    targets: [
        .target(
            name: "MileOne",
            path: "Sources/MileOne",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MileOneTests",
            dependencies: ["MileOne"],
            path: "Tests/MileOneTests"
        ),
    ]
)
