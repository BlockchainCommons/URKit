// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "URKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "URKit",
            targets: ["URKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/wolfmcnally/WolfBase", from: "5.0.0"),
        .package(url: "https://github.com/BlockchainCommons/BCSwiftDCBOR", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "URKit",
            dependencies: [
                "WolfBase",
                .product(name: "DCBOR", package: "BCSwiftDCBOR"),
            ]
        ),
        .testTarget(
            name: "URKitTests",
            dependencies: ["URKit"]
        ),
    ]
)
