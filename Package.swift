// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RootFont",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RootFontApp", targets: ["RootFontApp"])
    ],
    targets: [
        .executableTarget(
            name: "RootFontApp",
            path: "Sources/RootFontApp",
            exclude: [
                "Localization/CONTRIBUTING.md",
                "Localization/Locales/_template.swift"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        ),
        .testTarget(
            name: "RootFontAppTests",
            dependencies: ["RootFontApp"],
            path: "Tests/RootFontAppTests",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        )
    ]
)
