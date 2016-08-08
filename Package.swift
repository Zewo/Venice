import PackageDescription

let package = Package(
    name: "Venice",
    dependencies: [
        .Package(url: "https://github.com/VeniceX/CLibvenice.git", majorVersion: 0, minor: 6),
        .Package(url: "https://github.com/open-swift/C7.git", majorVersion: 0, minor: 0),
    ]
)
