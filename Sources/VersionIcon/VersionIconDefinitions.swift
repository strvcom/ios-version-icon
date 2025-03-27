//
//  VersionIconDefinitions.swift
//  VersionIcon
//
//  Created by Daniel Cech on 05/06/2020.
//

import AppKit
import Files
import Foundation
import Moderator
import ScriptToolkit
import SwiftShell

/// Icon overlay design style description
struct DesignStyle {
    var ribbon: String?
    var title: String?
    var titleFillColor: NSColor
    var titleStrokeColor: NSColor
    var titleStrokeWidth: Double
    var titleFont: String
    var titleSizeRatio: Double
    var horizontalTitlePositionRatio: Double
    var verticalTitlePositionRatio: Double
    var titleAlignment: String
    var versionStyle: String
}

/// Information about script running context
struct ScriptSetup {
    var appIcon: String
    var appIconOriginal: String
    var resourcesPath: String
}

/// Information about the modified app
struct AppSetup {
    var sourceRootPath: String
    var projectDir: String
    var infoPlistFile: String
    var appIconFolder: Folder
    var appIconContents: IconMetadata
    var originalAppIconFolder: Folder
    var originalAppIconContents: IconMetadata
}

// MARK: - Image JSON structs

/// Structure of Contents.json
struct IconMetadata: Codable {
    var images: [ImageInfo]

    func imageInfo(forSize size: String, scale: String) -> ImageInfo? {
        for image in images {
            if image.fits(size: size) && image.fits(scale: scale) {
                return image
            }
        }
        return nil
    }
}

/// Image description structure
struct ImageInfo: Codable {
    var size: String
    var idiom: String
    var filename: String?
    var scale: String?

    static let singleScale = "1x"

    func fits(size: String) -> Bool {
        self.size == size
    }

    func fits(scale: String?) -> Bool {
        self.scale ?? ImageInfo.singleScale == scale
    }
}

// MARK: - Helpers

/// Getting information about the app with modified icon
func getAppSetup(scriptSetup: ScriptSetup) throws -> AppSetup {
    #if DEBUGGING
        let sourceRootPath = "/Users/danielcech/Documents/ios-project-template"
        let projectDir = "/Users/danielcech/Documents/ios-project-template"
        let infoPlistFile = "Example/Application/Info.plist"
    #else
        guard
            let sourceRootPath = main.env["SRCROOT"],
            let projectDir = main.env["PROJECT_DIR"],
            let infoPlistFile = main.env["INFOPLIST_FILE"]
        else {
            print("Missing environment variables")
            throw ScriptError.moreInfoNeeded(message: "Missing required environment variables: SRCROOT, PROJECT_DIR, INFOPLIST_FILE. Please run script from Xcode script build phase.")
        }
    #endif

    print("  sourceRootPath: \(sourceRootPath)")
    print("  projectDir: \(projectDir)")
    print("  infoPlistFile: \(infoPlistFile)")

    let sourceFolder = try Folder(path: sourceRootPath)

    guard let appIconFolder = sourceFolder.findFirstFolder(name: "\(scriptSetup.appIcon).appiconset") else {
        throw ScriptError.folderNotFound(message: "\(scriptSetup.appIcon).appiconset - icon asset folder")
    }

    guard let originalAppIconFolder = sourceFolder.findFirstFolder(name: "\(scriptSetup.appIconOriginal).appiconset") else {
        throw ScriptError.folderNotFound(message: "\(scriptSetup.appIconOriginal).appiconset - source icon asset for modifications")
    }

    return try AppSetup(
        sourceRootPath: sourceRootPath,
        projectDir: projectDir,
        infoPlistFile: infoPlistFile,
        appIconFolder: appIconFolder,
        appIconContents: iconMetadata(iconFolder: appIconFolder),
        originalAppIconFolder: originalAppIconFolder,
        originalAppIconContents: iconMetadata(iconFolder: originalAppIconFolder)
    )
}

/// Getting information about the app icon images
func iconMetadata(iconFolder: Folder) throws -> IconMetadata {
    let contentsFile = try iconFolder.file(named: "Contents.json")
    let jsonData = try contentsFile.read()
    do {
        let iconMetadata = try JSONDecoder().decode(IconMetadata.self, from: jsonData)
        return iconMetadata
    } catch {
        throw ScriptError.generalError(message: String(describing: error))
    }
}

/// Get current version and build of the app in prefered format
func getVersionText(appSetup: AppSetup, designStyle: DesignStyle) -> String {
    #if DEBUGGING
        return "1.0 - 20"
    #endif

    let versionNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleShortVersionString", appSetup.infoPlistFile)
    let buildNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleVersion", appSetup.infoPlistFile)

    var versionNumber = versionNumberResult.stdout
    if versionNumber == "$(MARKETING_VERSION)" {
        versionNumber = main.env["MARKETING_VERSION"] ?? ""
    }

    var buildNumber = buildNumberResult.stdout
    if buildNumber == "$(CURRENT_PROJECT_VERSION)" {
        buildNumber = main.env["CURRENT_PROJECT_VERSION"] ?? ""
    }

    switch designStyle.versionStyle {
    case "dash":
        return "\(versionNumber) - \(buildNumber)"
    case "parenthesis":
        return "\(versionNumber)(\(buildNumber))"
    case "versionOnly":
        return "\(versionNumber)"
    case "buildOnly":
        return "\(buildNumber)"
    default:
        return ""
    }
}

/// Image resizing
func resizeImage(image: NSImage?, size: CGSize) -> NSImage? {
    guard let originalImage = image else {
        return nil
    }

    return resizeImageInternal(originalImage: originalImage, size: size)
}

/// Function to resize an image from a file
func resizeImage(fileName: String?, size: CGSize) -> NSImage? {
    guard let path = fileName, let originalImage = NSImage(contentsOfFile: path) else {
        return nil
    }

    return resizeImageInternal(originalImage: originalImage, size: size)
}

/// Internal helper function to resize an image
private func resizeImageInternal(originalImage: NSImage, size: CGSize) -> NSImage {
    // Create a new bitmap with exact pixel dimensions
    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    bitmapRep.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

    originalImage.draw(in: NSRect(origin: .zero, size: size),
                      from: NSRect(origin: .zero, size: originalImage.size),
                      operation: .copy,
                      fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    // Create a new NSImage with the exact representation
    let newImage = NSImage(size: size)
    newImage.addRepresentation(bitmapRep)

    return newImage
}

/// Generate icon overlay
func generateIcon(
    size: String,
    scale: String,
    realSize: CGSize,
    designStyle: DesignStyle,
    scriptSetup: ScriptSetup,
    appSetup: AppSetup
) throws {
    guard
        let originalAppIconFileName = appSetup.originalAppIconContents.imageInfo(forSize: size, scale: scale)?.filename,
        let originalAppIconFile = appSetup.originalAppIconFolder.findFirstFile(name: originalAppIconFileName)
    else {
        return
    }

    try restoreIcon(size: size, scale: scale, scriptSetup: scriptSetup, appSetup: appSetup)

    guard
        let appIconFileName = appSetup.appIconContents.imageInfo(forSize: size, scale: scale)?.filename,
        let appIconFile = appSetup.appIconFolder.findFirstFile(name: appIconFileName)
    else { return }

    print(appIconFileName.lastPathComponent)

    let version = getVersionText(appSetup: appSetup, designStyle: designStyle)

    let newSize = CGSize(
        width: realSize.width,
        height: realSize.height
    )

    //  Resizing ribbon
    let resizedRibbonImage = resizeImage(fileName: designStyle.ribbon, size: newSize)

    //  Resizing title
    let resizedTitleImage = resizeImage(fileName: designStyle.title, size: newSize)

    guard
        let iconImageData = try? Data(contentsOf: URL(fileURLWithPath: originalAppIconFile.path))
    else {
        return
    }

    let iconImage = NSImage(size: NSSize(width: 1024, height: 1024))
    if let bitmap = NSBitmapImageRep(data: iconImageData) {
        iconImage.addRepresentation(bitmap)
    }

    var combinedImage = iconImage
    if let unwrappedResizedRibbonImage = resizedRibbonImage {
        combinedImage = try combinedImage.combine(withImage: unwrappedResizedRibbonImage)
    }
    if let unwrappedResizedTitleImage = resizedTitleImage {
        combinedImage = try combinedImage.combine(withImage: unwrappedResizedTitleImage)
    }

    //  Annotating
    let resultImage = try combinedImage.annotate(
        text: version,
        font: designStyle.titleFont,
        size: realSize.width * CGFloat(designStyle.titleSizeRatio),
        horizontalTitlePosition: CGFloat(designStyle.horizontalTitlePositionRatio),
        verticalTitlePosition: CGFloat(designStyle.verticalTitlePositionRatio),
        titleAlignment: designStyle.titleAlignment,
        fill: designStyle.titleFillColor,
        stroke: designStyle.titleStrokeColor,
        strokeWidth: CGFloat(designStyle.titleStrokeWidth)
    )

    guard let resizedIcon = resizeImage(image: resultImage, size: newSize) else { return }

    try resizedIcon.savePNGRepresentationToURL(url: URL(fileURLWithPath: appIconFile.path), onlyChange: true)
}

/// Restore icon from original folder
func restoreIcon(
    size: String,
    scale: String,
    scriptSetup _: ScriptSetup,
    appSetup: AppSetup
) throws {
    guard
        let originalAppIconFileName = appSetup.originalAppIconContents.imageInfo(forSize: size, scale: scale)?.filename,
        let originalAppIconImageFile = appSetup.originalAppIconFolder.findFirstFile(name: originalAppIconFileName)
    else {
        return
    }

    guard
        let appIconFileName = appSetup.appIconContents.imageInfo(forSize: size, scale: scale)?.filename
    else {
        print("    Icon with size \(size):\(scale) not found")
        return
    }

    let appIconFilePath = appSetup.appIconFolder.path.appendingPathComponent(path: appIconFileName)

    if FileManager.default.fileExists(atPath: appIconFilePath) {
        try FileManager.default.removeItem(atPath: appIconFilePath)
    }

    let originalFile = try originalAppIconImageFile.copy(to: appSetup.appIconFolder)
    try originalFile.rename(to: appIconFileName)
}
