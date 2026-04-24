import AppKit
import Foundation

extension NSImage {
    var pngRepresentation: Data? {
        guard let tiff = tiffRepresentation,
              let tiffData = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        return tiffData.representation(using: .png, properties: [:])
    }

    private func imagesMatch(_ other: NSImage) -> Bool {
        tiffRepresentation == other.tiffRepresentation
    }

    func savePNGRepresentationToURL(url: URL, onlyChange: Bool = true) throws {
        guard let pngData = pngRepresentation else {
            throw ScriptError.generalError(message: "Unable to create PNG data")
        }

        if let originalImage = NSImage(contentsOf: url), onlyChange, imagesMatch(originalImage) {
            print("    Keeping original file - no change")
            return
        }

        try pngData.write(to: url, options: .atomicWrite)
    }

    func combine(withImage image: NSImage) throws -> NSImage {
        guard let foregroundData = image.tiffRepresentation,
              let foreground = CIImage(data: foregroundData),
              let backgroundData = tiffRepresentation,
              let background = CIImage(data: backgroundData)
        else {
            throw ScriptError.generalError(message: "Image processing error")
        }

        let filter = CIFilter(name: "CISourceOverCompositing")!
        filter.setDefaults()
        filter.setValue(foreground, forKey: "inputImage")
        filter.setValue(background, forKey: "inputBackgroundImage")

        guard let outputImage = filter.outputImage else {
            throw ScriptError.generalError(message: "Image processing error")
        }

        let rep = NSCIImageRep(ciImage: outputImage)
        let finalResult = NSImage(size: rep.size)
        finalResult.addRepresentation(rep)
        return finalResult
    }

    private func image(
        withText text: String,
        alignmentMode: NSTextAlignment,
        attributes: [NSAttributedString.Key: Any],
        horizontalTitlePosition: CGFloat,
        verticalTitlePosition: CGFloat
    ) -> NSImage {
        let text = text as NSString
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let textSize = text.boundingRect(with: size, options: options, attributes: attributes).size

        let offsetX: CGFloat
        switch alignmentMode {
        case .left:
            offsetX = 0
        case .center:
            offsetX = -textSize.width / 2
        case .right:
            offsetX = -textSize.width
        default:
            offsetX = 0
        }

        let point = NSPoint(
            x: size.width * horizontalTitlePosition + offsetX,
            y: size.height * verticalTitlePosition - textSize.height / 2
        )

        lockFocus()
        text.draw(at: point, withAttributes: attributes)
        unlockFocus()

        return self
    }

    func annotate(
        text: String,
        font: String,
        size: CGFloat,
        horizontalTitlePosition: CGFloat,
        verticalTitlePosition: CGFloat,
        titleAlignment: String,
        fill: NSColor,
        stroke: NSColor,
        strokeWidth: CGFloat
    ) throws -> NSImage {
        guard let titleFont = NSFont(name: font, size: size) else {
            throw ScriptError.argumentError(message: "Unable to find font \(font)")
        }

        let alignmentMode: NSTextAlignment
        switch titleAlignment {
        case "left":
            alignmentMode = .left
        case "right":
            alignmentMode = .right
        default:
            alignmentMode = .center
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignmentMode

        let fillText = image(
            withText: text,
            alignmentMode: alignmentMode,
            attributes: [
                .foregroundColor: fill,
                .font: titleFont,
                .paragraphStyle: paragraph,
            ],
            horizontalTitlePosition: horizontalTitlePosition,
            verticalTitlePosition: verticalTitlePosition
        )

        return fillText.image(
            withText: text,
            alignmentMode: alignmentMode,
            attributes: [
                .foregroundColor: NSColor.clear,
                .strokeColor: stroke,
                .strokeWidth: strokeWidth * size,
                .font: titleFont,
                .paragraphStyle: paragraph,
            ],
            horizontalTitlePosition: horizontalTitlePosition,
            verticalTitlePosition: verticalTitlePosition
        )
    }
}
