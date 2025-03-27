// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VersionIcon",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Files.git", from: "4.1.1"),
        .package(url: "https://github.com/DanielCech/Moderator.git", from: "0.5.1"),
        .package(url: "https://github.com/DanielCech/ScriptToolkit.git", .branch("master")),
        .package(url: "https://github.com/kareman/SwiftShell.git", from: "5.0.1"),
        .package(url: "https://github.com/kareman/FileSmith.git", from: "0.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "VersionIcon",
            dependencies: ["Files", "FileSmith", "SwiftShell", "ScriptToolkit", "Moderator"],
            swiftSettings:
            [
                // Macro definition - uncomment only when debugging
                // .define("DEBUGGING")
            ]
        ),
        .testTarget(
            name: "VersionIconTests",
            dependencies: ["VersionIcon"]
        ),
    ]
)
