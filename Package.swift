// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "Venice",
    dependencies: [
        .Package(url: "https://github.com/Zewo/CLibdill.git", majorVersion: 1)
    ]
)
