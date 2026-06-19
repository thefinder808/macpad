// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "macpad",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "macpad",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/macpad",
            linkerSettings: [
                // The binary ships inside macpad.app and must find
                // Sparkle.framework at Contents/Frameworks/. dyld searches
                // rpaths relative to the binary; without this the framework
                // only resolves when it happens to sit next to the binary
                // (which SPM-built apps don't do). build.sh embed_sparkle()
                // copies the framework into Contents/Frameworks/.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        )
    ]
)
