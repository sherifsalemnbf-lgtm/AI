// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlashCull",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FlashCullCore", targets: ["FlashCullCore"]),
        .executable(name: "flashcull", targets: ["flashcull"])
    ],
    targets: [
        .target(
            name: "FlashCullCore",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("Vision")
            ]
        ),
        .executableTarget(name: "flashcull", dependencies: ["FlashCullCore"]),
        .testTarget(name: "FlashCullCoreTests", dependencies: ["FlashCullCore"])
    ]
)
