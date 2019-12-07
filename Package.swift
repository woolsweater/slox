// swift-tools-version:5.0

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
            dependencies: ["loxvm-object"]
        ),
        .target(
            name: "loxvm-object",
            dependencies: []
        ),
        .testTarget(
            name: "LoxLibTests",
            dependencies: ["LoxLib"]
        ),
    ]
)
