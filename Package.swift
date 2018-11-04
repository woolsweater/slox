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
        .executable(
            name: "loxvm",
            targets: ["loxvm"]
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
        .target(
            name: "loxvm",
            dependencies: []
        ),
        .testTarget(
            name: "LoxLibTests",
            dependencies: ["LoxLib"]
        ),
    ]
)
