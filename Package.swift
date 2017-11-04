// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Venice",
    products: [
        .library(name: "Venice", targets: ["Venice"])
    ],
    dependencies: [
        .package(url: "https://github.com/Zewo/CLibdill.git", from: "2.0.0")
    ],
    targets: [
        .target(name: "Venice"),
        .testTarget(name: "VeniceTests", dependencies: ["Venice"]),
    ]
)
