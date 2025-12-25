// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sstv",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "sstv",
            targets: ["sstv"]
        )
    ],
    targets: [
        .executableTarget(
            name: "sstv",
            path: "Sources/sstv"
        ),
        .testTarget(
            name: "sstvTests",
            dependencies: ["sstv"],
            path: "Tests/sstvTests"
        )
    ]
)
