// swift-tools-version: 5.9
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
            targets: ["DonnaShared"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DonnaShared",
            dependencies: []),
    ]
)