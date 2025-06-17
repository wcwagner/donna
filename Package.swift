// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Donna",
  platforms: [.iOS(.v26)],
  products: [
    .library(name: "DonnaShared",  targets: ["DonnaShared"]),
    .library(name: "DonnaCore",    targets: ["DonnaCore"]),
    .library(name: "DonnaIntents", targets: ["DonnaIntents"]),
  ],
  targets: [
    // 1. Pure protocols + value types
    .target(name: "DonnaShared",
            path: "Modules/DonnaShared/Sources"),

    // 2. Heavy implementation – links AVFAudio, Speech, Combine
    .target(name: "DonnaCore",
            dependencies: ["DonnaShared"],
            path: "Modules/DonnaCore/Sources",
            swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])]),

    // 3. App Intents, Shortcut metadata, lightweight SwiftUI snippet views
    .target(name: "DonnaIntents",
            dependencies: ["DonnaShared"],
            path: "Modules/DonnaIntents/Sources",
            resources: [.process("Resources")]),

    .testTarget(name: "DonnaTests",
                dependencies: ["DonnaCore","DonnaShared"]),
  ]
)