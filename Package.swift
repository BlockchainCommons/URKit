// swift-tools-version:5.6

import PackageDescription

let package = Package(
    name: "URKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "URKit",
            targets: ["URKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wolfmcnally/WolfBase", from: "3.0.0")
    ],
    targets: [
        .target(
            name: "URKit",
            dependencies: ["WolfBase"],
            exclude: ["CBOR/README.md"]),
        .testTarget(
            name: "URKitTests",
            dependencies: ["URKit"]),
    ]
)
