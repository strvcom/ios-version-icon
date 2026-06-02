import AppKit
import CryptoKit
import Foundation

/// A record of all inputs that produced a generated icon. It is embedded into the
/// generated PNG as a human-readable JSON `tEXt` chunk and compared on the next run —
/// when no input changed, the icon is not regenerated and git sees no modification.
struct IconStateRecord: Codable, Equatable {
    var version: String
    var versionStyle: String
    var font: String
    var fillColor: String
    var strokeColor: String
    var strokeWidth: Double
    var titleSize: Double
    var horizontalTitlePosition: Double
    var verticalTitlePosition: Double
    var titleRotation: Double
    var titleAlignment: String
    var pixelSize: String
    var sourceIconHash: String
    var ribbonHash: String?
    var titleHash: String?
}

extension IconStateRecord {
    static let metadataKeyword = "VersionIcon"

    init(
        version: String,
        designStyle: DesignStyle,
        pixelSize: CGSize,
        sourceIconData: Data,
        ribbonData: Data?,
        titleData: Data?
    ) {
        self.version = version
        versionStyle = designStyle.versionStyle.rawValue
        font = designStyle.titleFont
        fillColor = designStyle.titleFillColor.hexString
        strokeColor = designStyle.titleStrokeColor.hexString
        strokeWidth = designStyle.titleStrokeWidth
        titleSize = designStyle.titleSizeRatio
        horizontalTitlePosition = designStyle.horizontalTitlePositionRatio
        verticalTitlePosition = designStyle.verticalTitlePositionRatio
        titleRotation = designStyle.titleRotation
        titleAlignment = designStyle.titleAlignment.rawValue
        self.pixelSize = "\(Int(pixelSize.width))x\(Int(pixelSize.height))"
        sourceIconHash = Self.hash(sourceIconData)
        ribbonHash = ribbonData.map(Self.hash)
        titleHash = titleData.map(Self.hash)
    }

    /// The record stored in an existing generated icon, if present.
    static func stored(in pngData: Data) -> IconStateRecord? {
        guard let json = PNGMetadata.textChunk(in: pngData, keyword: metadataKeyword) else { return nil }
        return try? JSONDecoder().decode(IconStateRecord.self, from: Data(json.utf8))
    }

    /// Returns the PNG data with this record embedded as a `tEXt` chunk.
    func embedded(into pngData: Data) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let json = try? encoder.encode(self) else { return nil }

        return PNGMetadata.insertingTextChunk(
            into: pngData,
            keyword: Self.metadataKeyword,
            text: String(decoding: json, as: UTF8.self)
        )
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension NSColor {
    var hexString: String {
        guard let srgb = usingColorSpace(.sRGB) else { return description }

        return String(
            format: "#%02X%02X%02X",
            Int(round(srgb.redComponent * 255)),
            Int(round(srgb.greenComponent * 255)),
            Int(round(srgb.blueComponent * 255))
        )
    }
}
