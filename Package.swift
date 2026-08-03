// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OnkyoMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OnkyoMac",
            path: "Sources/OnkyoMac"
        )
    ]
)
