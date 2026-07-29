// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HostBlock",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "HostBlockCore",
            resources: [.process("Resources/catalog-fallback.json")]
        ),
        .executableTarget(
            name: "HostBlock",
            dependencies: ["HostBlockCore"]
        ),
        .testTarget(
            name: "HostBlockCoreTests",
            dependencies: ["HostBlockCore"]
        ),
    ]
)
