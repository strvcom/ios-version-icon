// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VersionIcon",
    dependencies: [
      .package(url: "https://github.com/JohnSundell/Files.git", from: "2.0.0"),
      .package(url: "https://github.com/kareman/SwiftShell.git", from: "4.0.0"),
      .package(url: "https://github.com/DanielCech/Moderator.git", from: "0.0.0"),
      .package(url: "https://github.com/DanielCech/ScriptToolkit.git", from: "0.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "VersionIcon",
            dependencies: ["Files", "SwiftShell", "Moderator", "ScriptToolkit"]),
        .testTarget(
            name: "VersionIconTests",
            dependencies: ["VersionIcon"]),
    ]
)
