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
        verticalTitlePosition: CGFloat,
        rotation: CGFloat
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
        let textRect = NSRect(origin: point, size: textSize)
        let rotationCenter = NSPoint(x: textRect.midX, y: textRect.midY)

        lockFocus()
        guard NSGraphicsContext.current != nil else {
            unlockFocus()
            return self
        }

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rotationCenter.x, yBy: rotationCenter.y)
        transform.rotate(byDegrees: rotation)
        transform.translateX(by: -rotationCenter.x, yBy: -rotationCenter.y)
        transform.concat()
        text.draw(with: textRect, options: options, attributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        unlockFocus()

        return self
    }

    func annotate(
        text: String,
        font: String,
        size: CGFloat,
        horizontalTitlePosition: CGFloat,
        verticalTitlePosition: CGFloat,
        titleRotation: CGFloat,
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
            verticalTitlePosition: verticalTitlePosition,
            rotation: titleRotation
        )

        return fillText.image(
            withText: text,
            alignmentMode: alignmentMode,
            attributes: [
                .foregroundColor: NSColor.clear,
                .strokeColor: stroke,
                .strokeWidth: strokeWidth * 100,
                .font: titleFont,
                .paragraphStyle: paragraph,
            ],
            horizontalTitlePosition: horizontalTitlePosition,
            verticalTitlePosition: verticalTitlePosition,
            rotation: titleRotation
        )
    }
}

func resizeImage(image: NSImage?, size: CGSize) -> NSImage? {
    guard let originalImage = image else {
        return nil
    }

    return resizeImageInternal(originalImage: originalImage, size: size)
}

func resizeImage(fileName: String?, size: CGSize) -> NSImage? {
    guard let path = fileName, let originalImage = NSImage(contentsOfFile: path) else {
        return nil
    }

    return resizeImageInternal(originalImage: originalImage, size: size)
}

private func resizeImageInternal(originalImage: NSImage, size: CGSize) -> NSImage {
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

    originalImage.draw(
        in: NSRect(origin: .zero, size: size),
        from: NSRect(origin: .zero, size: originalImage.size),
        operation: .copy,
        fraction: 1.0
    )

    NSGraphicsContext.restoreGraphicsState()

    let newImage = NSImage(size: size)
    newImage.addRepresentation(bitmapRep)

    return newImage
}
