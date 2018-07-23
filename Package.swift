// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "slox",
    products: [
        .executable(
            name: "slox",
            targets: ["slox"]
        ),
        .library(
            name: "LoxLib",
            targets: ["LoxLib"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "slox",
            dependencies: ["LoxLib"]
        ),
        .target(
            name: "LoxLib",
            dependencies: []
        ),
        .testTarget(
            name: "LoxLibTests",
            dependencies: ["LoxLib"]
        ),
    ]
)
