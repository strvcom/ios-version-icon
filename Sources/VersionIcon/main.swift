import AppKit
import Files
import Foundation
import Moderator
import SwiftShell

// ========================================================================================================================================

// MARK: - Main script

let moderator = Moderator(description: "VersionIcon prepares iOS icon with ribbon, text and version info overlay")
moderator.usageFormText = "versionIcon <params>"

// ScriptSetup elements

let appIcon = moderator.add(Argument<String?>
    .optionWithValue("appIcon", name: "The name of app icon asset", description: "The asset that is modified by script.").default("AppIcon"))

let appIconOriginal = moderator.add(Argument<String?>
    .optionWithValue("appIconOriginal", name: "The name of original app icon asset", description: "This asset is used as backup of original icon.").default("AppIconOriginal"))

let outputAssetCatalog = moderator.add(Argument<String?>
    .optionWithValue(
        "outputAssetCatalog",
        name: "Generated asset catalog path",
        description: "Optional .xcassets directory where the generated app icon is written. When provided, source assets are not modified."
    ))

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

let titleRotation = moderator.add(Argument<String?>
    .optionWithValue("titleRotation", name: "Version Title Rotation", description: "Version title rotation in degrees from -180 to 180.").default("0"))

let titleAlignment = moderator.add(Argument<String?>
    .optionWithValue("titleAlignment", name: "Version Title Text Alignment", description: "Possible values are left, center, right.").default("center"))

let versionStyle = moderator.add(Argument<String?>
    .optionWithValue("versionStyle", name: "The format of version label", description: "Possible values are dash, parenthesis, parenthesisTwoLines, twoLines, versionOnly, buildOnly and empty.").default("dash"))

// AppSetup elements

let resourcesPath = moderator.add(Argument<String?>
    .optionWithValue("resources", name: "VersionIcon resources path", description: "Default path where Ribbons and Titles folders are located. It is not necessary to set when script is executed as a build phase in Xcode"))

let onError = moderator.add(Argument<String?>
    .optionWithValue("onError", name: "Error handling mode", description: "Possible values are fail and warn.").default("fail"))

let original = moderator.add(.option("original", description: "Use original icon with no modifications (for production)"))

let help = moderator.add(.option("help", description: "Shows this info summary"))

var errorHandlingMode: ErrorHandlingMode = .fail

do {
    try moderator.parse(lastValueWinsForRepeatedFlags(normalizedArguments(Array(CommandLine.arguments.dropFirst()))))

    if help.value {
        print(normalizedUsageText(moderator.usagetext))
        exit(0)
    }

    print("⌚️ Processing")

    guard let convertedErrorHandlingMode = ErrorHandlingMode(rawValue: onError.value) else {
        throw ScriptError.argumentError(message: "Invalid on-error argument")
    }
    errorHandlingMode = convertedErrorHandlingMode

    guard let resourcesPath = resourcesPath.value ?? main.env["PODS_ROOT"]?.appendingPathComponent(path: "VersionIcon/Bin") else {
        throw ScriptError.argumentError(message: "You must specify the resources path using --resources parameter")
    }

    let scriptSetup = ScriptSetup(
        appIcon: appIcon.value,
        appIconOriginal: appIconOriginal.value,
        outputAssetCatalog: outputAssetCatalog.value,
        resourcesPath: resourcesPath
    )
    let appSetup = try getAppSetup(scriptSetup: scriptSetup)
    let resolvedVariants = try resolveIconVariants(appSetup: appSetup)

    print("  Matched icon entries: \(resolvedVariants.variants.count)")
    for note in resolvedVariants.notes {
        print("⚠️ warning: \(note)")
    }

    if original.value {
        let outputs = try prepareRestoreOutputs(variants: resolvedVariants.variants)
        try applyOutputs(outputs)
        print("✅ Done")
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
    guard let convertedTitleRotation = Double(titleRotation.value), (-180.0 ... 180.0).contains(convertedTitleRotation) else {
        throw ScriptError.argumentError(message: "Invalid titleRotation argument")
    }
    guard let convertedTitleAlignment = TitleAlignment(rawValue: titleAlignment.value)
    else { throw ScriptError.argumentError(message: "Invalid titleAlignment argument") }
    guard let convertedVersionStyle = VersionStyle(rawValue: versionStyle.value)
    else { throw ScriptError.argumentError(message: "Invalid versionStyle argument") }
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
        titleRotation: convertedTitleRotation,
        titleAlignment: convertedTitleAlignment,
        versionStyle: convertedVersionStyle
    )

    let outputs = try generateIconOutputs(
        variants: resolvedVariants.variants,
        designStyle: designStyle,
        appSetup: appSetup
    )
    try applyOutputs(outputs)

    print("✅ Done")
} catch {
    if let printableError = error as? PrintableError {
        print(printableError.errorDescription)
    } else {
        print(error.localizedDescription)
    }

    if errorHandlingMode == .warn {
        print("⚠️ warning: VersionIcon failed but the build will continue because --on-error warn was used.")
        exit(0)
    }

    exit(Int32(error._code))
}

private func normalizedArguments(_ arguments: [String]) -> [String] {
    arguments.map { argument in
        switch argument {
        case "--on-error":
            "--onError"
        default:
            argument
        }
    }
}

private func normalizedUsageText(_ usageText: String) -> String {
    usageText.replacingOccurrences(of: "--onError", with: "--on-error")
}
