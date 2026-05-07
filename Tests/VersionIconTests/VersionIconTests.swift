import AppKit
import Foundation
import XCTest

final class VersionIconTests: XCTestCase {
    func testHelpPrintsUsage() throws {
        let result = try runVersionIcon(arguments: ["--help"])

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("versionIcon <params>"))
    }

    func testMissingResourcesReportsResourcesOption() throws {
        let result = try runVersionIcon(arguments: [])

        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("--resources parameter"))
    }

    func testOriginalModeFailsWhenRequiredIconFileIsMissing() throws {
        let projectRoot = try makeProjectFixture(
            appIconImages: legacyIconImages,
            originalAppIconImages: legacyIconImages,
            missingOriginalFileNames: ["Icon-60@2x.png"]
        )
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        let result = try runVersionIcon(
            arguments: [
                "--resources", repositoryRoot.appendingPathComponent("Bin").path,
                "--original",
            ],
            environment: [
                "SRCROOT": projectRoot.path,
                "PROJECT_DIR": projectRoot.path,
                "INFOPLIST_FILE": projectRoot.appendingPathComponent("Info.plist").path,
            ]
        )

        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("Source icon file"))
    }

    func testWarnModePrintsErrorButExitsZero() throws {
        let projectRoot = try makeProjectFixture(
            appIconImages: legacyIconImages,
            originalAppIconImages: legacyIconImages,
            missingOriginalFileNames: ["Icon-60@2x.png"]
        )
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        let result = try runVersionIcon(
            arguments: [
                "--resources", repositoryRoot.appendingPathComponent("Bin").path,
                "--original",
                "--on-error", "warn",
            ],
            environment: [
                "SRCROOT": projectRoot.path,
                "PROJECT_DIR": projectRoot.path,
                "INFOPLIST_FILE": projectRoot.appendingPathComponent("Info.plist").path,
            ]
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("Source icon file"))
        XCTAssertTrue(result.stdout.contains("build will continue"))
    }

    func testTitleRotationMustBeWithinBounds() throws {
        let projectRoot = try makeProjectFixture()
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        let result = try runVersionIcon(
            arguments: [
                "--resources", repositoryRoot.appendingPathComponent("Bin").path,
                "--titleRotation", "181",
            ],
            environment: [
                "SRCROOT": projectRoot.path,
                "PROJECT_DIR": projectRoot.path,
                "INFOPLIST_FILE": projectRoot.appendingPathComponent("Info.plist").path,
            ]
        )

        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("Invalid titleRotation argument"))
    }

    func testDynamicVariantDiscoverySupportsFlashcardsStyleIconSet() throws {
        let projectRoot = try makeProjectFixture(
            appIconImages: flashcardsStyleIconImages,
            originalAppIconImages: flashcardsStyleIconImages,
            infoPlistRelativePath: "Config/Info.plist",
            nestAssetsUnderProjectDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        let destinationIconURL = projectRoot
            .appendingPathComponent("App")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("AppIcon.appiconset")
            .appendingPathComponent("Flashcards.png")
        let originalIconData = try Data(contentsOf: destinationIconURL)

        let result = try runVersionIcon(
            arguments: [
                "--resources", repositoryRoot.appendingPathComponent("Bin").path,
                "--ribbon", "Blue-TopRight.png",
                "--title", "Devel-TopRight.png",
                "--titleSize", "0.15",
                "--fillColor", "#FFFFFF",
            ],
            environment: [
                "SRCROOT": projectRoot.path,
                "PROJECT_DIR": projectRoot.path,
                "INFOPLIST_FILE": "Config/Info.plist",
            ]
        )

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.stdout.contains("Matched icon entries: 11"))

        let updatedIconData = try Data(contentsOf: destinationIconURL)
        XCTAssertNotEqual(updatedIconData, originalIconData)
    }

    static var allTests = [
        ("testHelpPrintsUsage", testHelpPrintsUsage),
        ("testMissingResourcesReportsResourcesOption", testMissingResourcesReportsResourcesOption),
        ("testOriginalModeFailsWhenRequiredIconFileIsMissing", testOriginalModeFailsWhenRequiredIconFileIsMissing),
        ("testWarnModePrintsErrorButExitsZero", testWarnModePrintsErrorButExitsZero),
        ("testTitleRotationMustBeWithinBounds", testTitleRotationMustBeWithinBounds),
        ("testDynamicVariantDiscoverySupportsFlashcardsStyleIconSet", testDynamicVariantDiscoverySupportsFlashcardsStyleIconSet),
    ]
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private struct FixtureImage {
    let size: String
    let idiom: String
    let filename: String
    let scale: String?
    let platform: String?
}

private let legacyIconImages: [FixtureImage] = [
    FixtureImage(size: "60x60", idiom: "universal", filename: "Icon-60@2x.png", scale: "2x", platform: nil),
    FixtureImage(size: "60x60", idiom: "universal", filename: "Icon-60@3x.png", scale: "3x", platform: nil),
    FixtureImage(size: "76x76", idiom: "universal", filename: "Icon-76@2x.png", scale: "2x", platform: nil),
    FixtureImage(size: "83.5x83.5", idiom: "universal", filename: "Icon-83.5@2x.png", scale: "2x", platform: nil),
    FixtureImage(size: "1024x1024", idiom: "universal", filename: "Icon-1024@1x.png", scale: "1x", platform: nil),
]

private let flashcardsStyleIconImages: [FixtureImage] = [
    FixtureImage(size: "1024x1024", idiom: "universal", filename: "Flashcards.png", scale: nil, platform: "ios"),
    FixtureImage(size: "16x16", idiom: "mac", filename: "FlashcardsRounded(16x16).png", scale: "1x", platform: nil),
    FixtureImage(size: "16x16", idiom: "mac", filename: "FlashcardsRounded(32x32).png", scale: "2x", platform: nil),
    FixtureImage(size: "32x32", idiom: "mac", filename: "FlashcardsRounded(32x32) 1.png", scale: "1x", platform: nil),
    FixtureImage(size: "32x32", idiom: "mac", filename: "FlashcardsRounded(64x64).png", scale: "2x", platform: nil),
    FixtureImage(size: "128x128", idiom: "mac", filename: "FlashcardsRounded(128x128).png", scale: "1x", platform: nil),
    FixtureImage(size: "128x128", idiom: "mac", filename: "FlashcardsRounded(256x256) 1.png", scale: "2x", platform: nil),
    FixtureImage(size: "256x256", idiom: "mac", filename: "FlashcardsRounded(256x256) 2.png", scale: "1x", platform: nil),
    FixtureImage(size: "256x256", idiom: "mac", filename: "FlashcardsRounded(512x512) 1.png", scale: "2x", platform: nil),
    FixtureImage(size: "512x512", idiom: "mac", filename: "FlashcardsRounded(512x512) 2.png", scale: "1x", platform: nil),
    FixtureImage(size: "512x512", idiom: "mac", filename: "FlashcardsRounded.png", scale: "2x", platform: nil),
]

private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func makeTempProject() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeProjectFixture(
    appIconImages: [FixtureImage] = legacyIconImages,
    originalAppIconImages: [FixtureImage]? = nil,
    missingOriginalFileNames: Set<String> = [],
    infoPlistRelativePath: String = "Info.plist",
    nestAssetsUnderProjectDirectory: Bool = false
) throws -> URL {
    let projectRoot = try makeTempProject()
    let assetsRoot = nestAssetsUnderProjectDirectory
        ? projectRoot.appendingPathComponent("App/Resources/Assets.xcassets", isDirectory: true)
        : projectRoot

    try FileManager.default.createDirectory(at: assetsRoot, withIntermediateDirectories: true)

    try createAppIconSet(
        at: assetsRoot.appendingPathComponent("AppIcon.appiconset"),
        images: appIconImages
    )
    try createAppIconSet(
        at: assetsRoot.appendingPathComponent("AppIconOriginal.appiconset"),
        images: originalAppIconImages ?? appIconImages,
        missingFileNames: missingOriginalFileNames
    )

    let infoPlistURL = projectRoot.appendingPathComponent(infoPlistRelativePath)
    try FileManager.default.createDirectory(
        at: infoPlistURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let infoPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleShortVersionString</key>
        <string>1.2.3</string>
        <key>CFBundleVersion</key>
        <string>456</string>
    </dict>
    </plist>
    """
    try Data(infoPlist.utf8).write(to: infoPlistURL)

    return projectRoot
}

private func createAppIconSet(
    at url: URL,
    images: [FixtureImage],
    missingFileNames: Set<String> = []
) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    let entries = images.map { image -> [String: String] in
        var entry = [
            "size": image.size,
            "idiom": image.idiom,
            "filename": image.filename,
        ]

        if let scale = image.scale {
            entry["scale"] = scale
        }
        if let platform = image.platform {
            entry["platform"] = platform
        }

        return entry
    }

    let contents = ["images": entries]
    let jsonData = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try jsonData.write(to: url.appendingPathComponent("Contents.json"))

    for image in images where !missingFileNames.contains(image.filename) {
        try makePNG(at: url.appendingPathComponent(image.filename), size: 32)
    }
}

private func makePNG(at url: URL, size: Int) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.systemBlue.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "VersionIconTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create PNG data"])
    }

    try data.write(to: url)
}

private func runVersionIcon(arguments: [String], environment: [String: String] = [:]) throws -> ProcessResult {
    let process = Process()
    process.currentDirectoryURL = repositoryRoot
    process.executableURL = productsDirectory.appendingPathComponent("VersionIcon")
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
}

private var productsDirectory: URL {
    #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
    #else
        return Bundle.main.bundleURL
    #endif
}
