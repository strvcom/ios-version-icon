import Foundation

private enum IconSetKind: String {
    case source
    case destination
}

func resolveIconVariants(appSetup: AppSetup) throws -> ResolvedIconVariants {
    let sourceLookup = try buildImageLookup(metadata: appSetup.originalAppIconContents, kind: .source)
    let destinationLookup = try buildImageLookup(metadata: appSetup.appIconContents, kind: .destination)

    let sourceKeys = Set(sourceLookup.keys)
    let destinationKeys = Set(destinationLookup.keys)
    let matchedKeys = sourceKeys.intersection(destinationKeys).sorted {
        $0.description.localizedStandardCompare($1.description) == .orderedAscending
    }

    guard !matchedKeys.isEmpty else {
        throw ScriptError.generalError(
            message: """
            Unable to find matching icon entries between \(appSetup.originalAppIconFolder.path) and \(appSetup.appIconFolder.path).
            Source entries: \(describeEntries(from: appSetup.originalAppIconContents))
            Destination entries: \(describeEntries(from: appSetup.appIconContents))
            """
        )
    }

    var notes = [String]()

    let sourceOnlyKeys = sourceKeys.subtracting(destinationKeys).sorted {
        $0.description.localizedStandardCompare($1.description) == .orderedAscending
    }
    if !sourceOnlyKeys.isEmpty {
        notes.append(
            "Skipping \(sourceOnlyKeys.count) source-only icon entr\(sourceOnlyKeys.count == 1 ? "y" : "ies"): \(sourceOnlyKeys.map(\.description).joined(separator: "; "))"
        )
    }

    let destinationOnlyKeys = destinationKeys.subtracting(sourceKeys).sorted {
        $0.description.localizedStandardCompare($1.description) == .orderedAscending
    }
    if !destinationOnlyKeys.isEmpty {
        notes.append(
            "Skipping \(destinationOnlyKeys.count) destination-only icon entr\(destinationOnlyKeys.count == 1 ? "y" : "ies"): \(destinationOnlyKeys.map(\.description).joined(separator: "; "))"
        )
    }

    let variants = try matchedKeys.map { key -> ResolvedIconVariant in
        guard let sourceImage = sourceLookup[key], let sourceFileName = sourceImage.filename else {
            throw ScriptError.fileNotFound(message: "Source icon metadata for \(key.description)")
        }
        guard let sourceFile = appSetup.originalAppIconFolder.findFirstFile(name: sourceFileName) else {
            throw ScriptError.fileNotFound(message: "Source icon file \(sourceFileName) for \(key.description)")
        }

        guard let destinationImage = destinationLookup[key], let destinationFileName = destinationImage.filename else {
            throw ScriptError.fileNotFound(message: "Destination icon metadata for \(key.description)")
        }

        return ResolvedIconVariant(
            key: key,
            sourcePath: sourceFile.path,
            destinationPath: appSetup.appIconFolder.path.appendingPathComponent(path: destinationFileName),
            pixelSize: try resolvedPixelSize(size: key.size, scale: key.scale)
        )
    }

    return ResolvedIconVariants(variants: variants, notes: notes)
}

private func buildImageLookup(
    metadata: IconMetadata,
    kind: IconSetKind
) throws -> [IconVariantKey: ImageInfo] {
    var lookup = [IconVariantKey: ImageInfo]()

    for image in metadata.images where image.filename != nil {
        let key = image.variantKey
        if let existingImage = lookup[key] {
            let existingName = existingImage.filename ?? "<missing>"
            let newName = image.filename ?? "<missing>"
            throw ScriptError.generalError(
                message: "Duplicate \(kind.rawValue) icon metadata for \(key.description): \(existingName), \(newName)"
            )
        }

        lookup[key] = image
    }

    return lookup
}

private func describeEntries(from metadata: IconMetadata) -> String {
    let entries = metadata.images.compactMap { image -> String? in
        guard let filename = image.filename else {
            return nil
        }

        return "\(image.descriptor) -> \(filename)"
    }

    if entries.isEmpty {
        return "<none>"
    }

    return entries.sorted().joined(separator: "; ")
}

private func resolvedPixelSize(size: String, scale: String) throws -> CGSize {
    let sizeComponents = size.split(separator: "x")
    guard sizeComponents.count == 2,
          let width = Double(sizeComponents[0]),
          let height = Double(sizeComponents[1])
    else {
        throw ScriptError.generalError(message: "Unable to parse icon size: \(size)")
    }

    guard scale.hasSuffix("x"),
          let scaleMultiplier = Double(scale.dropLast())
    else {
        throw ScriptError.generalError(message: "Unable to parse icon scale: \(scale)")
    }

    return CGSize(width: width * scaleMultiplier, height: height * scaleMultiplier)
}
