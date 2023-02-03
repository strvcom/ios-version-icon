import Foundation
import AppKit
import Files
import SwiftShell
import Moderator
import ScriptToolkit


// ========================================================================================================================================
// MARK: - Main script

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
    
    print("⌚️ Processing")
    
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
        
        // iPad Pro App Icon @2x
        try restoreIcon(
            size: "83.5x83.5",
            scale: "2x",
            scriptSetup: scriptSetup,
            appSetup: appSetup
        )
        
        // Universal iOS marketing icon
        try restoreIcon(
            size: "1024x1024",
            scale: "1x",
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
    guard versionStyle.value == "dash" || versionStyle.value == "parenthesis" || versionStyle.value == "versionOnly" || versionStyle.value == "buildOnly" else { throw ScriptError.argumentError(message: "Invalid versionStyle argument") }
    guard let convertedTitleFillColor = NSColor(hexString: titleFillColor.value) else { throw ScriptError.argumentError(message: "Invalid fillcolor argument") }
    guard let convertedTitleStrokeColor = NSColor(hexString: titleStrokeColor.value) else { throw ScriptError.argumentError(message: "Invalid strokecolor argument") }
    guard let convertedTitleStrokeWidth = Double(titleStrokeWidth.value) else { throw ScriptError.argumentError(message: "Invalid strokewidth argument") }

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
    
    // iPad Pro App Icon @2x
    try generateIcon(
        size: "83.5x83.5",
        scale: "2x",
        realSize: CGSize(width: 167, height: 167),
        designStyle: designStyle,
        scriptSetup: scriptSetup,
        appSetup: appSetup
    )
    
    // Universal iOS marketing icon
    try generateIcon(
        size: "1024x1024",
        scale: "1x",
        realSize: CGSize(width: 1024, height: 1024),
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
