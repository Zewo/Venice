import PackageDescription

let package = Package(
    name: "Venice",
    targets: [
        Target(name: "CLibdill"),
        Target(name: "Venice", dependencies: ["CLibdill"]),
    ]
)
