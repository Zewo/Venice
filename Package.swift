import PackageDescription

let package = Package(
    name: "Venice",

    dependencies: [
        .Package(url: "https://github.com/Zewo/CLibdill.git", majorVersion: 1, minor: 0)
    ]

)
