//
//  VersionIconDefinitions.swift
//  VersionIcon
//
//  Created by Daniel Cech on 05/06/2020.
//

import Foundation
import AppKit
import Files
import SwiftShell
import Moderator
import ScriptToolkit

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
            if (image.size == size) && (image.scale == scale) {
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
    var scale: String
}


// MARK: - Helpers

/// Getting information about the app with modified icon
func getAppSetup(scriptSetup: ScriptSetup) throws -> AppSetup {
    guard
        let sourceRootPath = main.env["SRCROOT"],
        let projectDir = main.env["PROJECT_DIR"],
        let infoPlistFile = main.env["INFOPLIST_FILE"]
        else {
            print("Missing environment variables")
            throw ScriptError.moreInfoNeeded(message: "Missing required environment variables: SRCROOT, PROJECT_DIR, INFOPLIST_FILE. Please run script from Xcode script build phase.")
    }
    
    // For debugging purpuses only.
//    let sourceRootPath = "/Users/danielcech/Documents/[Development]/[Projects]/harbor-iOS"
//    let projectDir = "/Users/danielcech/Documents/[Development]/[Projects]/harbor-iOS"
//    let infoPlistFile = "Harbor/Application/Info.plist"

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
    
    return AppSetup(
        sourceRootPath: sourceRootPath,
        projectDir: projectDir,
        infoPlistFile: infoPlistFile,
        appIconFolder: appIconFolder,
        appIconContents: try iconMetadata(iconFolder: appIconFolder),
        originalAppIconFolder: originalAppIconFolder,
        originalAppIconContents: try iconMetadata(iconFolder: originalAppIconFolder)
    )
}

/// Getting information about the app icon images
func iconMetadata(iconFolder: Folder) throws -> IconMetadata {
    let contentsFile = try iconFolder.file(named: "Contents.json")
    let jsonData = try contentsFile.read()
    do {
        let iconMetadata = try JSONDecoder().decode(IconMetadata.self, from: jsonData)
        return iconMetadata
    }
    catch {
        print(error)
    }
    fatalError()
}

/// Get current version and build of the app in prefered format
func getVersionText(appSetup: AppSetup, designStyle: DesignStyle) -> String {
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
func resizeImage(fileName: String?, size: CGSize) -> NSImage? {
    let image: NSImage? = fileName.map { NSImage(contentsOfFile: $0) } ?? nil
    return image.map { try? $0.copy(size: size) } ?? nil
}

/// Generate icon overlay
func generateIcon(
    size: String,
    scale: String,
    realSize: CGSize,
    designStyle: DesignStyle,
    scriptSetup: ScriptSetup,
    appSetup: AppSetup) throws {

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
    
    let version = getVersionText(appSetup: appSetup, designStyle: designStyle)

    let newSize = CGSize(width: realSize.width / 2, height: realSize.height / 2)

    print("  Resizing ribbon")
    let resizedRibbonImage = resizeImage(fileName: designStyle.ribbon, size: newSize)

    print("  Resizing title")
    let resizedTitleImage = resizeImage(fileName: designStyle.title, size: newSize)

    let iconImageData = try Data(contentsOf: URL(fileURLWithPath: originalAppIconFile.path))
    guard let iconImage = NSImage(data: iconImageData) else { throw ScriptError.generalError(message: "Invalid image file") }

    var combinedImage = iconImage
    if let unwrappedResizedRibbonImage = resizedRibbonImage {
        combinedImage = try combinedImage.combine(withImage: unwrappedResizedRibbonImage)
    }
    if let unwrappedResizedTitleImage = resizedTitleImage {
        combinedImage = try combinedImage.combine(withImage: unwrappedResizedTitleImage)
    }

    print("  Annotating")
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

    let resizedIcon = try resultImage.copy(size: newSize)
    
    
    
    try resizedIcon.savePNGRepresentationToURL(url: URL(fileURLWithPath: appIconFile.path), onlyChange: true)
}

/// Restore icon from original folder
func restoreIcon(
    size: String,
    scale: String,
    scriptSetup: ScriptSetup,
    appSetup: AppSetup) throws {
    
    guard
        let originalAppIconFileName = appSetup.originalAppIconContents.imageInfo(forSize: size, scale: scale)?.filename,
        let originalAppIconImageFile = appSetup.originalAppIconFolder.findFirstFile(name: originalAppIconFileName)
    else {
        return
    }
    
    guard
        let appIconFileName = appSetup.appIconContents.imageInfo(forSize: size, scale: scale)?.filename
    else {
        throw ScriptError.fileNotFound(message: "Target icon record with \(size):\(scale) not found in \(appSetup.appIconFolder.path) folder")
    }
    
    let appIconFilePath = appSetup.appIconFolder.path.appendingPathComponent(path: appIconFileName)

    if FileManager.default.fileExists(atPath: appIconFilePath) {
        try FileManager.default.removeItem(atPath: appIconFilePath)
    }
    
    let originalFile = try originalAppIconImageFile.copy(to: appSetup.appIconFolder)
    try originalFile.rename(to: appIconFileName)
}
