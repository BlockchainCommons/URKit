// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "URKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v14),
        .macCatalyst(.v14)
    ],
    products: [
        .library(
            name: "URKit",
            targets: ["URKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/BlockchainCommons/BCSwiftDCBOR", from: "2.0.1"),
    ],
    targets: [
        .target(
            name: "URKit",
            dependencies: [
                .product(name: "DCBOR", package: "BCSwiftDCBOR"),
            ]
        ),
        .testTarget(
            name: "URKitTests",
            dependencies: [
                "URKit",
            ]
        ),
    ]
)
