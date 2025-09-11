// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConwayAPI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "conway-api",
            targets: ["ConwayAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(path: "../ConwayGameEngine"),
    ],
    targets: [
        .executableTarget(
            name: "ConwayAPI",
            dependencies: [
                "ConwayGameEngine",
                .product(name: "Vapor", package: "vapor"),
            ]),
        .testTarget(
            name: "ConwayAPITests",
            dependencies: [
                "ConwayAPI",
                .product(name: "XCTVapor", package: "vapor"),
            ]),
    ])
