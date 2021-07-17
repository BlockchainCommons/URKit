// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "URKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "URKit",
            targets: ["URKit"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "URKit",
            dependencies: [],
            exclude: ["CBOR/README.md"]),
        .testTarget(
            name: "URKitTests",
            dependencies: ["URKit"]),
    ]
)
