import PackageDescription

let package = Package(
    name: "Venice",
    dependencies: [
        .Package(url: "https://github.com/ZewoFlux/CLibvenice.git", majorVersion: 0, minor: 2)
    ]
)
