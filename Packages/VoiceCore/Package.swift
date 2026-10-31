// swift-tools-version:5.9
// SilkMic voice engine. Imported from NoNoise Mac (MIT, (c) 2025 Ghostkwebb, (c) 2026 ivalsaraj),
// modified by Delwer Hossain, 2026. See ../../Licenses/NoNoise-MIT.txt.
import PackageDescription

let package = Package(
    name: "VoiceCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VoiceCore", targets: ["VoiceCore"])
    ],
    targets: [
        // Lock-free C11-atomics SPSC float ring shared by realtime threads.
        .target(
            name: "CTapRing",
            path: "Sources/CTapRing"
        ),
        .target(
            name: "VoiceCore",
            dependencies: ["CTapRing"],
            path: "Sources/VoiceCore",
            resources: [
                .copy("Resources/DeepFilterNet3_Streaming.mlmodelc")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreML"),
                .linkedFramework("Accelerate")
            ]
        ),
        .testTarget(
            name: "VoiceCoreTests",
            dependencies: ["VoiceCore", "CTapRing"],
            path: "Tests/VoiceCoreTests"
        )
    ]
)
