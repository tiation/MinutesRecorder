// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MinutesRecorder",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MinutesRecorder",
            targets: ["MinutesRecorder"]),
    ],
    dependencies: [
        // Add dependencies here for speech recognition, audio processing, etc.
    ],
    targets: [
        .target(
            name: "MinutesRecorder",
            dependencies: []),
        .testTarget(
            name: "MinutesRecorderTests",
            dependencies: ["MinutesRecorder"]),
    ]
)
