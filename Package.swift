// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EarDesk",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "EarDeskCore",
            path: "Sources/EarDeskCore"
        ),
        .executableTarget(
            name: "EarDesk",
            dependencies: ["EarDeskCore"],
            path: "Sources/EarDesk"
        ),
        .testTarget(
            name: "EarDeskTests",
            dependencies: ["EarDeskCore"],
            path: "Tests/EarDeskTests"
        ),
    ]
)
