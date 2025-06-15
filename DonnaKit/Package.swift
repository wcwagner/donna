// DonnaKit/Package.swift
import PackageDescription

let package = Package(
    name: "DonnaKit",
    platforms: [.iOS(.v26)],
    products: [.library(name: "DonnaKit", targets: ["DonnaKit"])],
    targets: [
        .target(name: "DonnaKit"),
        .testTarget(name: "DonnaKitTests", dependencies: ["DonnaKit"])
    ]
)