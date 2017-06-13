// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Venice",
    products: [
        .library(
            name: "Venice",
            type: .dynamic,
            targets: [
               "Venice"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Zewo/CLibdill.git", .branch("swift-4"))
    ],
    targets: [
        .target(name: "Venice"),
        .testTarget(name: "VeniceTests", dependencies: ["Venice"]),
    ]
)
