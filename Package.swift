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
        .package(url: "https://github.com/wolfmcnally/WolfBase", from: "2.0.0")
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
