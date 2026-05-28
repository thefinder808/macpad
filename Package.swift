// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "macpad",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "macpad",
            path: "Sources/macpad"
        )
    ]
)
