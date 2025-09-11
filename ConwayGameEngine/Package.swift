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
        .executable(
            name: "conway-api",
            targets: ["ConwayAPI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    ],
    targets: [
        .target(
            name: "ConwayGameEngine",
            dependencies: []
        ),
        .executableTarget(
            name: "ConwayCLI",
            dependencies: ["ConwayGameEngine"]
        ),
        .executableTarget(
            name: "ConwayAPI",
            dependencies: [
                "ConwayGameEngine",
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "ConwayGameEngineTests",
            dependencies: ["ConwayGameEngine"]
        ),
        .testTarget(
            name: "ConwayAPITests",
            dependencies: [
                "ConwayAPI",
                .product(name: "XCTVapor", package: "vapor"),
            ]
        ),
    ]
)