// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DonnaShared",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "DonnaShared",
            targets: ["DonnaShared"]
        )
    ],
    targets: [
        .target(
            name: "DonnaShared",
            dependencies: []
        )
    ]
)
