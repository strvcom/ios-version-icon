import Foundation

struct IconMetadata: Codable {
    var images: [ImageInfo]
}

struct ImageInfo: Codable {
    var size: String
    var idiom: String
    var filename: String?
    var scale: String?
    var platform: String?
    var role: String?
    var subtype: String?

    static let singleScale = "1x"

    var normalizedScale: String {
        scale ?? ImageInfo.singleScale
    }

    var variantKey: IconVariantKey {
        IconVariantKey(
            size: size,
            scale: normalizedScale,
            idiom: idiom,
            platform: platform,
            role: role,
            subtype: subtype
        )
    }

    var descriptor: String {
        variantKey.description
    }
}

struct IconVariantKey: Hashable {
    var size: String
    var scale: String
    var idiom: String
    var platform: String?
    var role: String?
    var subtype: String?

    var description: String {
        var components = ["\(size) @\(scale)", idiom]

        if let platform {
            components.append("platform=\(platform)")
        }
        if let role {
            components.append("role=\(role)")
        }
        if let subtype {
            components.append("subtype=\(subtype)")
        }

        return components.joined(separator: ", ")
    }
}

struct ResolvedIconVariant {
    var key: IconVariantKey
    var sourcePath: String
    var destinationPath: String
    var pixelSize: CGSize
}

struct ResolvedIconVariants {
    var variants: [ResolvedIconVariant]
    var notes: [String]
}

struct FileOutput {
    var destinationPath: String
    var data: Data
    var label: String
}
