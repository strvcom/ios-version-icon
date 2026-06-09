import AppKit
import Foundation

func generateIconOutputs(
    variants: [ResolvedIconVariant],
    designStyle: DesignStyle,
    appSetup: AppSetup
) throws -> [FileOutput] {
    try validateDesignStyle(designStyle)
    let version = try getVersionText(appSetup: appSetup, designStyle: designStyle)

    let ribbonData = try designStyle.ribbon.map { try imageResourceData(path: $0, kind: "ribbon") }
    let titleData = try designStyle.title.map { try imageResourceData(path: $0, kind: "title") }

    return try variants.compactMap { variant in
        print("  \(variant.key.description)")

        let iconImageData: Data
        do {
            iconImageData = try Data(contentsOf: URL(fileURLWithPath: variant.sourcePath))
        } catch {
            throw ScriptError.fileNotFound(message: "Unable to read original icon image: \(variant.sourcePath)")
        }

        let state = IconStateRecord(
            version: version,
            designStyle: designStyle,
            pixelSize: variant.pixelSize,
            sourceIconData: iconImageData,
            ribbonData: ribbonData,
            titleData: titleData
        )

        if let existingData = try? Data(contentsOf: URL(fileURLWithPath: variant.destinationPath)),
           IconStateRecord.stored(in: existingData) == state {
            print("    Keeping original file - no change (\(variant.key.description))")
            return nil
        }

        let resizedRibbonImage = resizeImage(fileName: designStyle.ribbon, size: variant.pixelSize)
        if designStyle.ribbon != nil, resizedRibbonImage == nil {
            throw ScriptError.generalError(message: "Unable to load ribbon image: \(designStyle.ribbon!)")
        }

        let resizedTitleImage = resizeImage(fileName: designStyle.title, size: variant.pixelSize)
        if designStyle.title != nil, resizedTitleImage == nil {
            throw ScriptError.generalError(message: "Unable to load title image: \(designStyle.title!)")
        }

        let iconImage = NSImage(size: variant.pixelSize)
        guard let bitmap = NSBitmapImageRep(data: iconImageData) else {
            throw ScriptError.generalError(message: "Unable to decode original icon image: \(variant.sourcePath)")
        }
        iconImage.addRepresentation(bitmap)

        var combinedImage = iconImage
        if let resizedRibbonImage {
            combinedImage = try combinedImage.combine(withImage: resizedRibbonImage)
        }
        if let resizedTitleImage {
            combinedImage = try combinedImage.combine(withImage: resizedTitleImage)
        }

        let resultImage = try combinedImage.annotate(
            text: version,
            font: designStyle.titleFont,
            size: variant.pixelSize.width * CGFloat(designStyle.titleSizeRatio),
            horizontalTitlePosition: CGFloat(designStyle.horizontalTitlePositionRatio),
            verticalTitlePosition: CGFloat(designStyle.verticalTitlePositionRatio),
            titleRotation: CGFloat(designStyle.titleRotation),
            titleAlignment: designStyle.titleAlignment.rawValue,
            fill: designStyle.titleFillColor,
            stroke: designStyle.titleStrokeColor,
            strokeWidth: CGFloat(designStyle.titleStrokeWidth)
        )

        guard let resizedIcon = resizeImage(image: resultImage, size: variant.pixelSize) else {
            throw ScriptError.generalError(message: "Unable to resize generated icon for \(variant.key.description)")
        }
        guard let outputData = resizedIcon.pngRepresentation else {
            throw ScriptError.generalError(message: "Unable to create PNG data for \(variant.key.description)")
        }
        guard let stampedData = state.embedded(into: outputData) else {
            throw ScriptError.generalError(message: "Unable to embed VersionIcon metadata for \(variant.key.description)")
        }

        return FileOutput(
            destinationPath: variant.destinationPath,
            data: stampedData,
            label: variant.key.description
        )
    }
}

private func imageResourceData(path: String, kind: String) throws -> Data {
    do {
        return try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
        throw ScriptError.fileNotFound(message: "Unable to read \(kind) image: \(path)")
    }
}

func prepareRestoreOutputs(variants: [ResolvedIconVariant]) throws -> [FileOutput] {
    try variants.map { variant in
        let sourceURL = URL(fileURLWithPath: variant.sourcePath)
        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: sourceURL)
        } catch {
            throw ScriptError.fileNotFound(message: "Unable to read original icon image: \(variant.sourcePath)")
        }

        return FileOutput(
            destinationPath: variant.destinationPath,
            data: sourceData,
            label: variant.key.description
        )
    }
}

func applyOutputs(_ outputs: [FileOutput]) throws {
    var seenDestinations = Set<String>()

    for output in outputs {
        if !seenDestinations.insert(output.destinationPath).inserted {
            throw ScriptError.generalError(message: "Duplicate destination path detected: \(output.destinationPath)")
        }

        let destinationURL = URL(fileURLWithPath: output.destinationPath)
        if let existingData = try? Data(contentsOf: destinationURL), existingData == output.data {
            print("    Keeping original file - no change (\(output.label))")
            continue
        }

        try output.data.write(to: destinationURL, options: .atomic)
    }
}

private func validateDesignStyle(_ designStyle: DesignStyle) throws {
    try validateImageResource(fileName: designStyle.ribbon, kind: "ribbon")
    try validateImageResource(fileName: designStyle.title, kind: "title")

    guard NSFont(name: designStyle.titleFont, size: 12) != nil else {
        throw ScriptError.argumentError(message: "Unable to find font \(designStyle.titleFont)")
    }
}
