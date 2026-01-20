// swift-tools-version: 6.2

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
            path: "Sources/BabbleApp",
            linkerSettings: [
                .unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "MultitouchSupport"])
            ]
        ),
        .testTarget(
            name: "BabbleAppTests",
            dependencies: ["BabbleApp"],
            path: "Tests/BabbleAppTests"
        )
    ]
)
