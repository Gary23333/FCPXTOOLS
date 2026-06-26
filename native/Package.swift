// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FCPXToolbox",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FCPXToolbox",
            path: "Sources/FCPXToolbox",
            resources: [
                .process("Resources/Fonts")
            ]
        ),
        .testTarget(
            name: "FCPXToolboxTests",
            dependencies: ["FCPXToolbox"],
            path: "Tests/FCPXToolboxTests"
        )
    ]
)
