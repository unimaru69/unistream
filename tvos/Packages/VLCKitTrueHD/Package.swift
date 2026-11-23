// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "VLCKitTrueHD",
    platforms: [.tvOS("17.0")],
    products: [.library(name: "VLCKitSPM", targets: ["VLCKitSPM"])],
    targets: [
        .binaryTarget(name: "TVVLCKit", path: "Artifacts/TVVLCKit.xcframework"),
        .target(name: "VLCKitSPM", dependencies: ["TVVLCKit"], linkerSettings: [
            .linkedFramework("CoreText"), .linkedFramework("AVFoundation"),
            .linkedFramework("AudioToolbox"), .linkedFramework("OpenGLES"),
            .linkedFramework("VideoToolbox"), .linkedFramework("CoreMedia"),
            .linkedLibrary("c++"), .linkedLibrary("xml2"), .linkedLibrary("z"),
            .linkedLibrary("bz2"), .linkedLibrary("iconv"),
        ]),
    ]
)
