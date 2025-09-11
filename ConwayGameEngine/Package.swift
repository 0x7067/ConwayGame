// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConwayGameEngine",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ConwayGameEngine",
            targets: ["ConwayGameEngine"]
        ),
        .executable(
            name: "conway-cli",
            targets: ["ConwayCLI"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ConwayGameEngine",
            dependencies: []
        ),
        .executableTarget(
            name: "ConwayCLI",
            dependencies: ["ConwayGameEngine"]
        ),
        .testTarget(
            name: "ConwayGameEngineTests",
            dependencies: ["ConwayGameEngine"]
        ),
    ]
)