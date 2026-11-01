// swift-tools-version:5.9
// whisper.cpp (MIT, ggml-org) as a prebuilt XCFramework, used for optional Bengali-script dictation.
import PackageDescription

let package = Package(
    name: "WhisperCpp",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WhisperCpp", targets: ["WhisperCpp"])
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-b5454-xcframework.zip",
            checksum: "e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b"
        ),
        .target(name: "WhisperCpp", dependencies: ["whisper"], path: "Sources/WhisperCpp")
    ]
)
