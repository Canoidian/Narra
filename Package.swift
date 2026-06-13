// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "NarraV2",
    platforms: [.macOS(.v14)],
    dependencies: [
        // STT: whisper.cpp Swift bindings (local fallback)
        // .package(url: "...", from: "..."),
        // LLM: MLX Swift (local fallback)
        // .package(url: "...", from: "..."),
    ],
    targets: [
        .executableTarget(
            name: "NarraV2",
            dependencies: [],
            path: "Sources/NarraV2",
            swiftSettings: [.swiftLanguageVersion(.v6)]
        ),
    ]
)
