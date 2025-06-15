// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DonnaCore",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DonnaCore",
            targets: ["DonnaCore"]
        ),
    ],
    .targets: [
        .target(name: "DonnaCore", dependencies: ["DonnaKit"]),
        .testTarget(name: "DonnaCoreTests", dependencies: ["DonnaCore"])
    ]
)
