// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sstv",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SSTVCore",
            targets: ["SSTVCore"]
        ),
        .executable(
            name: "sstv",
            targets: ["sstv"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SSTVCore",
            path: "Sources/SSTVCore"
        ),
        .executableTarget(
            name: "sstv",
            dependencies: [
                "SSTVCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/sstv"
        ),
        .testTarget(
            name: "sstvTests",
            dependencies: ["SSTVCore"],
            path: "Tests/sstvTests"
        )
    ]
)
