// swift-tools-version:5.2

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
            dependencies: []),
        .testTarget(
            name: "URKitTests",
            dependencies: ["URKit"]),
    ]
)
