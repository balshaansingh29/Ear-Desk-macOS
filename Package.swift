// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NothingX",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "NothingXCore",
            path: "Sources/NothingXCore"
        ),
        .executableTarget(
            name: "NothingX",
            dependencies: ["NothingXCore"],
            path: "Sources/NothingX"
        ),
        .testTarget(
            name: "NothingXTests",
            dependencies: ["NothingXCore"],
            path: "Tests/NothingXTests"
        ),
    ]
)
