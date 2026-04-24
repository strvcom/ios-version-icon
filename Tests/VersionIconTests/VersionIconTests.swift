import AppKit
import class Foundation.Bundle
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
        let projectRoot = try makeProjectFixture(missingOriginalFirstVariantFile: true)
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
        XCTAssertTrue(result.stdout.contains("Original icon file"))
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

    static var allTests = [
        ("testHelpPrintsUsage", testHelpPrintsUsage),
        ("testMissingResourcesReportsResourcesOption", testMissingResourcesReportsResourcesOption),
        ("testOriginalModeFailsWhenRequiredIconFileIsMissing", testOriginalModeFailsWhenRequiredIconFileIsMissing),
        ("testTitleRotationMustBeWithinBounds", testTitleRotationMustBeWithinBounds),
    ]
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private let iconVariants: [(size: String, scale: String, filename: String)] = [
    ("60x60", "2x", "Icon-60@2x.png"),
    ("60x60", "3x", "Icon-60@3x.png"),
    ("76x76", "2x", "Icon-76@2x.png"),
    ("83.5x83.5", "2x", "Icon-83.5@2x.png"),
    ("1024x1024", "1x", "Icon-1024@1x.png"),
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

private func makeProjectFixture(missingOriginalFirstVariantFile: Bool = false) throws -> URL {
    let projectRoot = try makeTempProject()
    try createAppIconSet(at: projectRoot.appendingPathComponent("AppIcon.appiconset"), missingFirstVariantFile: false)
    try createAppIconSet(at: projectRoot.appendingPathComponent("AppIconOriginal.appiconset"), missingFirstVariantFile: missingOriginalFirstVariantFile)

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
    try Data(infoPlist.utf8).write(to: projectRoot.appendingPathComponent("Info.plist"))

    return projectRoot
}

private func createAppIconSet(at url: URL, missingFirstVariantFile: Bool) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

    let images = iconVariants.map { variant in
        [
            "size": variant.size,
            "idiom": "universal",
            "filename": variant.filename,
            "scale": variant.scale,
        ]
    }

    let contents = ["images": images]
    let jsonData = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try jsonData.write(to: url.appendingPathComponent("Contents.json"))

    for (index, variant) in iconVariants.enumerated() {
        if missingFirstVariantFile && index == 0 {
            continue
        }

        try makePNG(at: url.appendingPathComponent(variant.filename), size: 8)
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
