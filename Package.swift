// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JagtFokusCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v18)
    ],
    products: [
        .library(name: "JagtFokusCore", targets: ["JagtFokusCore"])
    ],
    targets: [
        .target(name: "JagtFokusCore"),
        .testTarget(
            name: "JagtFokusCoreTests",
            dependencies: ["JagtFokusCore"]
        )
    ]
)
