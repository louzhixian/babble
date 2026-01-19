// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BabbleApp",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Babble", targets: ["BabbleApp"])
    ],
    targets: [
        .executableTarget(
            name: "BabbleApp",
            path: "Sources/BabbleApp"
        )
    ]
)
