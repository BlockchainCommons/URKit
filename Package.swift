// swift-tools-version:5.7

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
        .package(url: "https://github.com/BlockchainCommons/BCSwiftDCBOR", from: "0.11.0"),
        .package(url: "https://github.com/BlockchainCommons/BCSwiftCrypto.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "URKit",
            dependencies: [
                .product(name: "DCBOR", package: "BCSwiftDCBOR"),
                .product(name: "BCCrypto", package: "BCSwiftCrypto"),
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
