import PackageDescription

let package = Package(
    name: "Venice",
    dependencies: [
        .Package(url: "https://github.com/Zewo/CLibvenice.git", majorVersion: 0, minor: 4),
    ],
    targets: [Target(name: "Venice", dependencies: ["CLibvenice"])]
)
