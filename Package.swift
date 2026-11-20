// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dusk",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DuskCore"),
        .executableTarget(name: "Dusk", dependencies: ["DuskCore"]),
        .testTarget(name: "DuskCoreTests", dependencies: ["DuskCore"]),
    ]
)
