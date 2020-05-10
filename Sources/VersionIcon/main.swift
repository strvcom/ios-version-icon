import Foundation
import AppKit
import Files
import SwiftShell
import Moderator
import ScriptToolkit

struct DesignStyle {
    var ribbon: String?
    var title: String?
    var fillColor: NSColor
    var strokeColor: NSColor
    var strokeWidth: Double
    var font: String
    var titleSizeRatio: Double
    var horizontalTitlePositionRatio: Double
    var verticalTitlePositionRatio: Double
    var titleAlignment: String
}

struct ScriptSetup {
    var appIcon: String
    var appIconOriginal: String
    var scriptPath: String
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
    var filename: String
    var scale: String
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

// MARK: - Helpers

func getAppSetup(scriptSetup: ScriptSetup) throws -> AppSetup {
    // TODO: uncomment, temporary
//    guard
//        let sourceRootPath = main.env["SRCROOT"],
//        let projectDir = main.env["PROJECT_DIR"],
//        let infoPlistFile = main.env["INFOPLIST_FILE"]
//        else {
//            print("Missing environment variables")
//            throw ScriptError.moreInfoNeeded(message: "Missing required environment variables: SRCROOT, PROJECT_DIR, INFOPLIST_FILE")
//    }
    
    let sourceRootPath = "/Users/dan/Documents/[Development]/[Projects]/RoboticArmApp"
    let projectDir = "/Users/dan/Documents/[Development]/[Projects]/RoboticArmApp"
    let infoPlistFile = "Arm/Info.plist"


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
    let contentsFile = try iconFolder.file(at: "Contents.json")
    let jsonData = try contentsFile.read()
    let iconMetadata = try JSONDecoder().decode(IconMetadata.self, from: jsonData)
    return iconMetadata
}

func getVersionText(appSetup: AppSetup) -> String {
    let versionNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleShortVersionString", appSetup.projectDir.appendingPathComponent(path: appSetup.infoPlistFile))
    let buildNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleVersion", appSetup.projectDir.appendingPathComponent(path: appSetup.infoPlistFile))
    return "\(versionNumberResult.stdout) - \(buildNumberResult.stdout)"
}

func resizeImage(fileName: String?, size: CGSize) -> NSImage? {
    let ribbonImage: NSImage? = fileName.map { NSImage(contentsOfFile: $0) } ?? nil
    return ribbonImage.map { try? $0.copy(size: size) } ?? nil
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
    
    let version = getVersionText(appSetup: appSetup)

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
        font: designStyle.font,
        size: realSize.width * CGFloat(designStyle.titleSizeRatio),
        horizontalTitlePosition: CGFloat(designStyle.horizontalTitlePositionRatio),
        verticalTitlePosition: CGFloat(designStyle.verticalTitlePositionRatio),
        titleAlignment: designStyle.titleAlignment,
        fill: designStyle.fillColor,
        stroke: designStyle.strokeColor,
        strokeWidth: CGFloat(designStyle.strokeWidth)
    )

    let resizedIcon = try resultImage.copy(size: newSize)

    try resizedIcon.savePNGRepresentationToURL(url: URL(fileURLWithPath: appIconFile.path))
}

func restoreIcon(_ icon: String) throws {
    guard
        let sourceRootPath = main.env["SRCROOT"]
    else {
        print("Missing environment variables")
        throw ScriptError.moreInfoNeeded(message: "Missing required environment variables: SRCROOT, PROJECT_DIR, INFOPLIST_FILE")
    }

    let sourceFolder = try Folder(path: sourceRootPath)

    guard let originalAppIconFolder = sourceFolder.findFirstFolder(name: "AppIconOriginal.appiconset") else {
        throw ScriptError.folderNotFound(message: "AppIconOriginal.appiconset - source icon asset for modifications")
    }

    guard let baseImageFile = originalAppIconFolder.findFirstFile(name: icon) else {
        throw ScriptError.fileNotFound(message: "\(icon) in AppIconOriginal.appiconset folder")
    }

    guard let appIconFolder = sourceFolder.findFirstFolder(name: "AppIcon.appiconset") else {
        throw ScriptError.folderNotFound(message: "AppIcon.appiconset - icon asset folder")
    }
    let targetPath = appIconFolder.path.appendingPathComponent(path: icon)

    try FileManager.default.removeItem(atPath: targetPath)
    try baseImageFile.copy(to: appIconFolder)
}


// ========================================================================================================================================


let moderator = Moderator(description: "VersionIcon prepares iOS icon with ribbon, text and version info overlay")
moderator.usageFormText = "versionIcon <params>"

let appIcon = moderator.add(Argument<String?>
    .optionWithValue("appIcon", name: "The name of app icon asset", description: "The asset that is modified by script.").default("AppIcon"))

let appIconOriginal = moderator.add(Argument<String?>
.optionWithValue("appIconOriginal", name: "The name of original app icon asset", description: "This asset is used as backup of original icon.").default("AppIconOriginal"))

var ribbon = moderator.add(Argument<String?>
    .optionWithValue("ribbon", name: "Icon ribbon color", description: "Name of PNG file in Ribbons folder or absolute path to Ribbon image"))

var title = moderator.add(Argument<String?>
    .optionWithValue("title", name: "Icon ribbon title", description: "Name of PNG file in Titles folder or absolute path to Title image"))

let titleFillColor = moderator.add(Argument<String?>
    .optionWithValue("fillColor", name: "Title fill color", description: "The fill color of version title in #xxxxxx hexa format.").default("#FFFFFF"))

let titleStrokeColor = moderator.add(Argument<String?>
    .optionWithValue("strokeColor", name: "Title stroke color", description: "The stroke color of version title in #xxxxxx hexa format.").default("#000000"))

let titleFont = moderator.add(Argument<String?>
    .optionWithValue("font", name: "Version label font", description: "Font used for version title.").default("Impact"))

let titleSize = moderator.add(Argument<String?>
    .optionWithValue("titleSize", name: "Version Title Size Ratio", description: "Version title size related to icon width.").default("0.2"))

let horizontalTitlePosition = moderator.add(Argument<String?>
    .optionWithValue("horizontalTitlePosition", name: "Version Title Size Ratio", description: "Version title position related to icon width.").default("0.5"))

let verticalTitlePosition = moderator.add(Argument<String?>
    .optionWithValue("verticalTitlePosition", name: "Version Title Size Ratio", description: "Version title position related to icon width.").default("0.2"))

let titleAlignment = moderator.add(Argument<String?>
    .optionWithValue("titleAlignment", name: "Version Title Text Alignment", description: "Possible values are left, center, right.").default("center"))

let strokeWidth = moderator.add(Argument<String?>
    .optionWithValue("strokeWidth", name: "Version Title Stroke Width", description: "Version title stroke width related to icon width.").default("0.03"))

let resourcesPath = moderator.add(Argument<String?>
    .optionWithValue("resources", name: "VersionIcon resources path", description: "Path where Ribbons and Titles folders are located. It is not necessary to set when script is executed as a build phase in Xcode"))

let iPhone = moderator.add(.option("iphone", description: "Generate iPhone icons"))

let iPad = moderator.add(.option("ipad", description: "Generate iPad icons"))

let original = moderator.add(.option("original", description: "Use original icon with no modifications (for production)"))

do {
    try moderator.parse()
    
    guard iPhone.value || iPad.value else {
        print(moderator.usagetext+"\n")
        throw ScriptError.argumentError(message: "You must enter at least one of parameters --iphone or --ipad")
    }

    guard let basePath = resourcesPath.value ?? main.env["PODS_ROOT"]?.appendingPathComponent(path: "VersionIcon/Bin") else {
        throw ScriptError.argumentError(message: "You must specify the script path using --scriptPath parameter")
    }

    guard !original.value else {
        if iPhone.value {
            try restoreIcon("AppIcon60x60@2x.png")

            try restoreIcon("AppIcon60x60@3x.png")
        }

        if iPad.value {
            try restoreIcon("AppIcon76x76~ipad.png")

            try restoreIcon("AppIcon76x76@2x~ipad.png")
        }
        exit(0)
    }

    if let unwrappedRibbon = ribbon.value, unwrappedRibbon.lastPathComponent == unwrappedRibbon {
        ribbon.value = basePath.appendingPathComponent(path: "Ribbons/\(unwrappedRibbon)")
    }

    if let unwrappedTitle = title.value, unwrappedTitle.lastPathComponent == unwrappedTitle {
        title.value = basePath.appendingPathComponent(path: "Titles/\(unwrappedTitle)")
    }

    guard let titleSizeRatio = Double(titleSize.value) else { throw ScriptError.argumentError(message: "Invalid titlesize argument") }
    guard let horizontalTitlePosition = Double(horizontalTitlePosition.value) else { throw ScriptError.argumentError(message: "Invalid horizontalTitlePosition argument") }
    guard let verticalTitlePosition = Double(verticalTitlePosition.value) else { throw ScriptError.argumentError(message: "Invalid verticalTitlePosition argument") }
    guard titleAlignment.value == "left" || titleAlignment.value == "center" || titleAlignment.value == "right" else { throw ScriptError.argumentError(message: "Invalid titleAlignment argument") }
    guard let strokeWidth = Double(strokeWidth.value) else { throw ScriptError.argumentError(message: "Invalid strokewidth argument") }
    guard let fillColor = NSColor(hexString: titleFillColor.value) else { throw ScriptError.argumentError(message: "Invalid fillcolor argument") }
    guard let strokeColor = NSColor(hexString: titleStrokeColor.value) else { throw ScriptError.argumentError(message: "Invalid strokecolor argument") }

    print("⌚️ Processing")

    let designStyle = DesignStyle(
        ribbon: ribbon.value,
        title: title.value,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        font: titleFont.value,
        titleSizeRatio: titleSizeRatio,
        horizontalTitlePositionRatio: horizontalTitlePosition,
        verticalTitlePositionRatio: verticalTitlePosition,
        titleAlignment: titleAlignment.value
    )
    
    let scriptSetup = ScriptSetup(appIcon: appIcon.value, appIconOriginal: appIconOriginal.value, scriptPath: basePath)
    let appSetup = try getAppSetup(scriptSetup: scriptSetup)
    
    if iPhone.value {
        try generateIcon(
            size: "60x60",
            scale: "2x",
            realSize: CGSize(width: 120, height: 120),
            designStyle: designStyle,
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
        
        try generateIcon(
            size: "60x60",
            scale: "3x",
            realSize: CGSize(width: 180, height: 180),
            designStyle: designStyle,
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
    }

    if iPad.value {
        try generateIcon(
            size: "76x76",
            scale: "1x",
            realSize: CGSize(width: 76, height: 76),
            designStyle: designStyle,
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
        
        try generateIcon(
            size: "76x76",
            scale: "2x",
            realSize: CGSize(width: 152, height: 152),
            designStyle: designStyle,
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
    }

    print("✅ Done")
}
catch {
    if let printableError = error as? PrintableError { print(printableError.errorDescription) }
    else {
        print(error.localizedDescription)
    }

    exit(Int32(error._code))
}
