import Foundation
import AppKit
import Files
import SwiftShell
import Moderator
import ScriptToolkit

func generateIcon(
    _ icon: String,
    size: CGSize,
    ribbon: String,
    title: String,
    fillColor: NSColor,
    strokeColor: NSColor,
    strokeWidth: Double,
    font: String,
    titleSizeRatio: Double,
    horizontalTitlePositionRatio: Double,
    verticalTitlePositionRatio: Double,
    titleAlignment: String,
    scriptPath: String) throws {

    print(icon)

//    guard
//        let sourceRootPath = main.env["SRCROOT"],
//        let projectDir = main.env["PROJECT_DIR"],
//        let infoPlistFile = main.env["INFOPLIST_FILE"]
//        else {
//            print("Missing environment variables")
//            throw ScriptError.moreInfoNeeded(message: "Missing required environment variables: SRCROOT, PROJECT_DIR, INFOPLIST_FILE")
//    }

    // Comment
    let sourceRootPath = "/Users/dan/Documents/[Development]/[Projects]/RoboticArmApp"
    let projectDir = "/Users/dan/Documents/[Development]/[Projects]/RoboticArmApp"
    let infoPlistFile = "Arm/Info.plist"

    print("  sourceRootPath: \(sourceRootPath)")
    print("  projectDir: \(projectDir)")
    print("  infoPlistFile: \(infoPlistFile)")

    let versionNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleShortVersionString", projectDir.appendingPathComponent(path: infoPlistFile))
    let buildNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleVersion", projectDir.appendingPathComponent(path: infoPlistFile))
    let version = "\(versionNumberResult.stdout) - \(buildNumberResult.stdout)"

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
    print("  targetPath: \(targetPath)")

    let newSize = CGSize(width: size.width / 2, height: size.height / 2)

    let ribbonsDirPath = scriptPath.appendingPathComponent(path: "Ribbons")
    let ribbonPath = ribbonsDirPath.appendingPathComponent(path: ribbon)

    let titlesDirPath = scriptPath.appendingPathComponent(path: "Titles")
    let titlePath = titlesDirPath.appendingPathComponent(path: title)

    print("  Resizing ribbon")
    guard let ribbonImage = NSImage(contentsOfFile: ribbonPath) else { throw ScriptError.generalError(message: "Invalid image file") }
    let resizedRibbonImage = try ribbonImage.copy(size: newSize)

    print("  Resizing title")
    guard let titleImage = NSImage(contentsOfFile: titlePath) else { throw ScriptError.generalError(message: "Invalid image file") }
    let resizedTitleImage = try titleImage.copy(size: newSize)

    let iconImageData = try Data(contentsOf: URL(fileURLWithPath: baseImageFile.path))
    guard let iconImage = NSImage(data: iconImageData) else { throw ScriptError.generalError(message: "Invalid image file") }

    let combinedImage = try iconImage.combine(withImage: resizedRibbonImage).combine(withImage: resizedTitleImage)

    print("  Annotating")
    let resultImage = try combinedImage.annotate(
        text: version,
        font: font,
        size: size.width * CGFloat(titleSizeRatio),
        horizontalTitlePosition: CGFloat(horizontalTitlePositionRatio),
        verticalTitlePosition: CGFloat(verticalTitlePositionRatio),
        titleAlignment: titleAlignment,
        fill: fillColor,
        stroke: strokeColor,
        strokeWidth: CGFloat(strokeWidth))

    let resizedIcon = try resultImage.copy(size: newSize)

    try resizedIcon.savePNGRepresentationToURL(url: URL(fileURLWithPath: targetPath))
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


let moderator = Moderator(description: "VersionIcon prepares iOS icon with ribbon, text and version info overlay")
moderator.usageFormText = "versionIcon <params>"

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

let iPhone = moderator.add(.option("iphone", description: "Generate iPhone icons"))

let iPad = moderator.add(.option("ipad", description: "Generate iPad icons"))

let original = moderator.add(.option("original", description: "Use original icon with no modifications (for production)"))

do {
//     try moderator.parse(["--ribbon", "Red.png", "--title", "Devel.png", "--iphone", "--font", "Arial", "--titleSize", "0.5", "--fillColor", "#AF003C", "--strokeColor", "#EEEEEE"])
    
    try moderator.parse(["--original"])
//    try moderator.parse()
    
    let scriptPath = main.env["PODS_ROOT"]?.appendingPathComponent(path: "VersionIcon/Bin")
    
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
        ribbon.value = scriptPath?.appendingPathComponent(path: "Ribbons/\(unwrappedRibbon)")
    }
    
    if let unwrappedTitle = title.value, unwrappedTitle.lastPathComponent == unwrappedTitle {
        title.value = scriptPath?.appendingPathComponent(path: "Titles/\(unwrappedTitle)")
    }
    
    guard let unwrappedRibbon = ribbon.value, let unwrappedTitle = title.value, let unwrappedScriptPath = scriptPath else {
        print(moderator.usagetext)
        exit(0)
    }
    
    guard let titleSizeRatio = Double(titleSize.value) else { throw ScriptError.argumentError(message: "Invalid titlesize argument") }
    guard let horizontalTitlePosition = Double(horizontalTitlePosition.value) else { throw ScriptError.argumentError(message: "Invalid horizontalTitlePosition argument") }
    guard let verticalTitlePosition = Double(verticalTitlePosition.value) else { throw ScriptError.argumentError(message: "Invalid verticalTitlePosition argument") }
    guard titleAlignment.value == "left" || titleAlignment.value == "center" || titleAlignment.value == "right" else { throw ScriptError.argumentError(message: "Invalid titleAlignment argument") }
    guard let strokeWidth = Double(strokeWidth.value) else { throw ScriptError.argumentError(message: "Invalid strokewidth argument") }
    guard let fillColor = NSColor(hexString: titleFillColor.value) else { throw ScriptError.argumentError(message: "Invalid fillcolor argument") }
    guard let strokeColor = NSColor(hexString: titleStrokeColor.value) else { throw ScriptError.argumentError(message: "Invalid strokecolor argument") }
    
    print("⌚️ Processing")

    if iPhone.value {
        try generateIcon(
            "AppIcon60x60@2x.png",
            size: CGSize(width: 120, height: 120),
            ribbon: unwrappedRibbon,
            title: unwrappedTitle,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            font: titleFont.value,
            titleSizeRatio: titleSizeRatio,
            horizontalTitlePositionRatio: horizontalTitlePosition,
            verticalTitlePositionRatio: verticalTitlePosition,
            titleAlignment: titleAlignment.value,
            scriptPath: unwrappedScriptPath
        )

        try generateIcon(
            "AppIcon60x60@3x.png",
            size: CGSize(width: 180, height: 180),
            ribbon: unwrappedRibbon,
            title: unwrappedTitle,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            font: titleFont.value,
            titleSizeRatio: titleSizeRatio,
            horizontalTitlePositionRatio: horizontalTitlePosition,
            verticalTitlePositionRatio: verticalTitlePosition,
            titleAlignment: titleAlignment.value,
            scriptPath: unwrappedScriptPath
        )
    }

    if iPad.value {
        try generateIcon(
            "AppIcon76x76~ipad.png",
            size: CGSize(width: 76, height: 76),
            ribbon: unwrappedRibbon,
            title: unwrappedTitle,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            font: titleFont.value,
            titleSizeRatio: titleSizeRatio,
            horizontalTitlePositionRatio: horizontalTitlePosition,
            verticalTitlePositionRatio: verticalTitlePosition,
            titleAlignment: titleAlignment.value,
            scriptPath: unwrappedScriptPath
        )

        try generateIcon(
            "AppIcon76x76@2x~ipad.png",
            size: CGSize(width: 152, height: 152),
            ribbon: unwrappedRibbon,
            title: unwrappedTitle,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            font: titleFont.value,
            titleSizeRatio: titleSizeRatio,
            horizontalTitlePositionRatio: horizontalTitlePosition,
            verticalTitlePositionRatio: verticalTitlePosition,
            titleAlignment: titleAlignment.value,
            scriptPath: unwrappedScriptPath
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
