// swift-tools-version: 6.0

// SPDX-License-Identifier: (see LICENSE)
// Mayam — Swift Package Manager Manifest

import PackageDescription

let package = Package(
    name: "Mayam",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "mayam",
            targets: ["MayamServer"]
        ),
        .library(
            name: "MayamCore",
            targets: ["MayamCore"]
        ),
        .library(
            name: "MayamWeb",
            targets: ["MayamWeb"]
        ),
        .executable(
            name: "mayam-cli",
            targets: ["MayamCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Raster-Lab/DICOMKit.git", branch: "main"),
        .package(url: "https://github.com/Raster-Lab/J2KSwift.git", branch: "main"),
        .package(url: "https://github.com/Raster-Lab/JLSwift.git", branch: "main"),
        .package(url: "https://github.com/Raster-Lab/JXLSwift.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.3.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.26.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        // MARK: - MayamServer (Main Entry Point)
        .executableTarget(
            name: "MayamServer",
            dependencies: [
                "MayamCore",
                "MayamWeb"
            ]
        ),

        // MARK: - MayamCore (Core PACS Engine)
        .target(
            name: "MayamCore",
            dependencies: [
                .product(name: "DICOMKit", package: "DICOMKit"),
                .product(name: "DICOMNetwork", package: "DICOMKit"),
                .product(name: "J2KCore", package: "J2KSwift"),
                .product(name: "J2KCodec", package: "J2KSwift"),
                .product(name: "J2K3D", package: "J2KSwift"),
                .product(name: "JPEGLS", package: "JLSwift"),
                .product(name: "JXLSwift", package: "JXLSwift"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Crypto", package: "swift-crypto")
            ],
            resources: [
                .copy("Database/Migrations")
            ]
        ),

        // MARK: - MayamWeb (DICOMweb & Admin REST API)
        .target(
            name: "MayamWeb",
            dependencies: [
                "MayamCore",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Crypto", package: "swift-crypto")
            ]
        ),

        // MARK: - MayamAdmin (Web Console Static Assets)
        .target(
            name: "MayamAdmin",
            dependencies: [],
            resources: [
                .copy("Assets")
            ]
        ),

        // MARK: - MayamCLI (Command-Line Tools)
        .executableTarget(
            name: "MayamCLI",
            dependencies: [
                "MayamCore"
            ]
        ),

        // MARK: - Test Targets
        .testTarget(
            name: "MayamCoreTests",
            dependencies: [
                "MayamCore",
                .product(name: "NIOEmbedded", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "MayamWebTests",
            dependencies: ["MayamWeb", "MayamCore"]
        )
    ]
)
