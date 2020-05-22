import Foundation
import AppKit
import Files
import SwiftShell
import Moderator
import ScriptToolkit

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

struct ScriptSetup {
    var appIcon: String
    var appIconOriginal: String
    var resourcesPath: String
}

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

struct ImageInfo: Codable {
    var size: String
    var idiom: String
    var filename: String?
    var scale: String
}


// MARK: - Helpers

func getAppSetup(scriptSetup: ScriptSetup) throws -> AppSetup {
    // TODO: uncomment, temporary
    guard
        let sourceRootPath = main.env["SRCROOT"],
        let projectDir = main.env["PROJECT_DIR"],
        let infoPlistFile = main.env["INFOPLIST_FILE"]
        else {
            print("Missing environment variables")
            throw ScriptError.moreInfoNeeded(message: "Missing required environment variables: SRCROOT, PROJECT_DIR, INFOPLIST_FILE")
    }
    
    // For debugging purpuses
//    let sourceRootPath = "/Users/danielcech/Documents/[Development]/[Projects]/harbor-iOS"
//    let projectDir = "/Users/danielcech/Documents/[Development]/[Projects]/harbor-iOS"
//    let infoPlistFile = "/Users/danielcech/Documents/[Development]/[Projects]/harbor-iOS/Harbor/Application/Info.plist"


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

func getVersionText(appSetup: AppSetup, designStyle: DesignStyle) -> String {
    let versionNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleShortVersionString", appSetup.infoPlistFile)
    let buildNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleVersion", appSetup.infoPlistFile)
    
    // For debugging purpuses
//    var versionNumber = "1.0"
//    var buildNumber = "4"
    
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

func resizeImage(fileName: String?, size: CGSize) -> NSImage? {
    let image: NSImage? = fileName.map { NSImage(contentsOfFile: $0) } ?? nil
    return image.map { try? $0.copy(size: size) } ?? nil
}

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
    else { return }
    
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

    try resizedIcon.savePNGRepresentationToURL(url: URL(fileURLWithPath: appIconFile.path))
}

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
        let appIconFileName = appSetup.appIconContents.imageInfo(forSize: size, scale: scale)?.filename,
        let appIconImageFile = appSetup.appIconFolder.findFirstFile(name: appIconFileName)
    else {
        throw ScriptError.fileNotFound(message: "Target icon with \(size):\(scale) not found in \(appSetup.appIconFolder.path) folder")
    }

    try FileManager.default.removeItem(atPath: appIconImageFile.path)
    try originalAppIconImageFile.copy(to: appSetup.appIconFolder)
}


// ========================================================================================================================================


let moderator = Moderator(description: "VersionIcon prepares iOS icon with ribbon, text and version info overlay")
moderator.usageFormText = "versionIcon <params>"

// ScriptSetup elements

let appIcon = moderator.add(Argument<String?>
    .optionWithValue("appIcon", name: "The name of app icon asset", description: "The asset that is modified by script.").default("AppIcon"))

let appIconOriginal = moderator.add(Argument<String?>
.optionWithValue("appIconOriginal", name: "The name of original app icon asset", description: "This asset is used as backup of original icon.").default("AppIconOriginal"))

// DesignStyle elements

var ribbon = moderator.add(Argument<String?>
    .optionWithValue("ribbon", name: "Icon ribbon color", description: "Name of PNG file in Ribbons folder or absolute path to Ribbon image"))

var title = moderator.add(Argument<String?>
    .optionWithValue("title", name: "Icon ribbon title", description: "Name of PNG file in Titles folder or absolute path to Title image"))

let titleFillColor = moderator.add(Argument<String?>
    .optionWithValue("fillColor", name: "Title fill color", description: "The fill color of version title in #xxxxxx hexa format.").default("#FFFFFF"))

let titleStrokeColor = moderator.add(Argument<String?>
    .optionWithValue("strokeColor", name: "Title stroke color", description: "The stroke color of version title in #xxxxxx hexa format.").default("#000000"))

let titleStrokeWidth = moderator.add(Argument<String?>
    .optionWithValue("strokeWidth", name: "Version Title Stroke Width", description: "Version title stroke width related to icon width.").default("0.03"))

let titleFont = moderator.add(Argument<String?>
    .optionWithValue("font", name: "Version label font", description: "Font used for version title.").default("Impact"))

let titleSizeRatio = moderator.add(Argument<String?>
    .optionWithValue("titleSize", name: "Version Title Size Ratio", description: "Version title size related to icon width.").default("0.25"))

let horizontalTitlePositionRatio = moderator.add(Argument<String?>
    .optionWithValue("horizontalTitlePosition", name: "Version Title Size Ratio", description: "Version title position related to icon width.").default("0.5"))

let verticalTitlePositionRatio = moderator.add(Argument<String?>
    .optionWithValue("verticalTitlePosition", name: "Version Title Size Ratio", description: "Version title position related to icon width.").default("0.2"))

let titleAlignment = moderator.add(Argument<String?>
    .optionWithValue("titleAlignment", name: "Version Title Text Alignment", description: "Possible values are left, center, right.").default("center"))

let versionStyle = moderator.add(Argument<String?>
    .optionWithValue("versionStyle", name: "The format of version label", description: "Possible values are dash, parenthesis, versionOnly, buildOnly.").default("dash"))

// AppSetup elements

let resourcesPath = moderator.add(Argument<String?>
    .optionWithValue("resources", name: "VersionIcon resources path", description: "Default path where Ribbons and Titles folders are located. It is not necessary to set when script is executed as a build phase in Xcode"))

let original = moderator.add(.option("original", description: "Use original icon with no modifications (for production)"))

let help = moderator.add(.option("help", description: "Shows this info summary"))

do {
    try moderator.parse()
    
    if help.value {
        print(moderator.usagetext)
        exit(0)
    }

    guard let resourcesPath = resourcesPath.value ?? main.env["PODS_ROOT"]?.appendingPathComponent(path: "VersionIcon/Bin") else {
        throw ScriptError.argumentError(message: "You must specify the resources path using --resourcesPath parameter")
    }
    
    let scriptSetup = ScriptSetup(appIcon: appIcon.value, appIconOriginal: appIconOriginal.value, resourcesPath: resourcesPath)
    let appSetup = try getAppSetup(scriptSetup: scriptSetup)

    guard !original.value else {
            // iPhone App Icon @2x
        try restoreIcon(
            size: "60x60",
            scale: "2x",
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
        
        // iPhone App Icon @3x
        try restoreIcon(
            size: "60x60",
            scale: "3x",
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )

        // iPad App Icon @2x
        try restoreIcon(
            size: "76x76",
            scale: "2x",
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
        
        // iPad App Icon @3x
        try restoreIcon(
            size: "76x76",
            scale: "3x",
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
        exit(0)
    }

    if let unwrappedRibbon = ribbon.value, unwrappedRibbon.lastPathComponent == unwrappedRibbon {
        ribbon.value = resourcesPath.appendingPathComponent(path: "Ribbons/\(unwrappedRibbon)")
    }

    if let unwrappedTitle = title.value, unwrappedTitle.lastPathComponent == unwrappedTitle {
        title.value = resourcesPath.appendingPathComponent(path: "Titles/\(unwrappedTitle)")
    }

    guard let convertedTitleSizeRatio = Double(titleSizeRatio.value) else { throw ScriptError.argumentError(message: "Invalid titlesize argument") }
    guard let convertedHorizontalTitlePosition = Double(horizontalTitlePositionRatio.value) else { throw ScriptError.argumentError(message: "Invalid horizontalTitlePosition argument") }
    guard let convertedVerticalTitlePosition = Double(verticalTitlePositionRatio.value) else { throw ScriptError.argumentError(message: "Invalid verticalTitlePosition argument") }
    guard titleAlignment.value == "left" || titleAlignment.value == "center" || titleAlignment.value == "right" else { throw ScriptError.argumentError(message: "Invalid titleAlignment argument") }
    guard versionStyle.value == "dash" || titleAlignment.value == "parenthesis" || titleAlignment.value == "versionOnly" || titleAlignment.value == "buildOnly" else { throw ScriptError.argumentError(message: "Invalid versionStyle argument") }
    guard let convertedTitleFillColor = NSColor(hexString: titleFillColor.value) else { throw ScriptError.argumentError(message: "Invalid fillcolor argument") }
    guard let convertedTitleStrokeColor = NSColor(hexString: titleStrokeColor.value) else { throw ScriptError.argumentError(message: "Invalid strokecolor argument") }
    guard let convertedTitleStrokeWidth = Double(titleStrokeWidth.value) else { throw ScriptError.argumentError(message: "Invalid strokewidth argument") }

    print("⌚️ Processing")

    let designStyle = DesignStyle(
        ribbon: ribbon.value,
        title: title.value,
        titleFillColor: convertedTitleFillColor,
        titleStrokeColor: convertedTitleStrokeColor,
        titleStrokeWidth: convertedTitleStrokeWidth,
        titleFont: titleFont.value,
        titleSizeRatio: convertedTitleSizeRatio,
        horizontalTitlePositionRatio: convertedHorizontalTitlePosition,
        verticalTitlePositionRatio: convertedVerticalTitlePosition,
        titleAlignment: titleAlignment.value,
        versionStyle: versionStyle.value
    )
    
    // iPhone App Icon @2x
    try generateIcon(
        size: "60x60",
        scale: "2x",
        realSize: CGSize(width: 120, height: 120),
        designStyle: designStyle,
        scriptSetup: scriptSetup,
        appSetup: appSetup
    )
    
    // iPhone App Icon @3x
    try generateIcon(
        size: "60x60",
        scale: "3x",
        realSize: CGSize(width: 180, height: 180),
        designStyle: designStyle,
        scriptSetup: scriptSetup,
        appSetup: appSetup
    )

    // iPad App Icon @2x
    try generateIcon(
        size: "76x76",
        scale: "2x",
        realSize: CGSize(width: 152, height: 152),
        designStyle: designStyle,
        scriptSetup: scriptSetup,
        appSetup: appSetup
    )
    
    // iPad App Icon @3x
    try generateIcon(
        size: "76x76",
        scale: "3x",
        realSize: CGSize(width: 228, height: 228),
        designStyle: designStyle,
        scriptSetup: scriptSetup,
        appSetup: appSetup
    )

    print("✅ Done")
}
catch {
    if let printableError = error as? PrintableError { print(printableError.errorDescription) }
    else {
        print(error.localizedDescription)
    }

    exit(Int32(error._code))
}
