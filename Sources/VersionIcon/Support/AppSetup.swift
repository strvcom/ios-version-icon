import AppKit
import Files
import Foundation
import SwiftShell

func validateImageResource(fileName: String?, kind: String) throws {
    guard let path = fileName else {
        return
    }

    guard FileManager.default.fileExists(atPath: path) else {
        throw ScriptError.fileNotFound(message: "\(kind) image: \(path)")
    }

    guard NSImage(contentsOfFile: path) != nil else {
        throw ScriptError.generalError(message: "Unable to load \(kind) image: \(path)")
    }
}

func getAppSetup(scriptSetup: ScriptSetup) throws -> AppSetup {
    #if DEBUGGING
        // Enter testing values from your project
        let sourceRootPath = ""
        let projectDir = ""
        let infoPlistFile = ""
    #else
        guard
            let sourceRootPath = main.env["SRCROOT"],
            let projectDir = main.env["PROJECT_DIR"],
            let infoPlistFile = main.env["INFOPLIST_FILE"]
        else {
            print("Missing environment variables")
            throw ScriptError.moreInfoNeeded(message: "Missing required environment variables: SRCROOT, PROJECT_DIR, INFOPLIST_FILE. Please run script from Xcode script build phase.")
        }
    #endif

    print("  sourceRootPath: \(sourceRootPath)")
    print("  projectDir: \(projectDir)")
    print("  infoPlistFile: \(infoPlistFile)")

    let sourceFolder = try Folder(path: sourceRootPath)
    let resolvedInfoPlistFile = try resolveInfoPlistPath(
        infoPlistFile: infoPlistFile,
        projectDir: projectDir,
        sourceRootPath: sourceRootPath
    )

    guard let originalAppIconFolder = try locateAppIconFolder(
        named: scriptSetup.appIconOriginal,
        projectDir: projectDir,
        sourceRootFolder: sourceFolder
    ) else {
        throw ScriptError.folderNotFound(message: "\(scriptSetup.appIconOriginal).appiconset - source icon asset for modifications")
    }

    let appIconFolder: Folder
    if let outputAssetCatalog = scriptSetup.outputAssetCatalog {
        let outputAppIconFolderPath = outputAssetCatalog.appendingPathComponent(path: "\(scriptSetup.appIcon).appiconset")

        let outputURL = URL(fileURLWithPath: outputAppIconFolderPath).standardizedFileURL
        let originalURL = URL(fileURLWithPath: originalAppIconFolder.path).standardizedFileURL
        guard outputURL != originalURL else {
            throw ScriptError.argumentError(message: "Generated asset catalog must not contain the original app icon")
        }

        try prepareGeneratedAppIconFolder(
            at: outputAppIconFolderPath,
            sourceFolder: originalAppIconFolder
        )

        appIconFolder = try Folder(path: outputAppIconFolderPath)
    } else {
        guard let existingAppIconFolder = try locateAppIconFolder(
            named: scriptSetup.appIcon,
            projectDir: projectDir,
            sourceRootFolder: sourceFolder
        ) else {
            throw ScriptError.folderNotFound(message: "\(scriptSetup.appIcon).appiconset - icon asset folder")
        }

        appIconFolder = existingAppIconFolder
    }

    return try AppSetup(
        sourceRootPath: sourceRootPath,
        projectDir: projectDir,
        infoPlistFile: resolvedInfoPlistFile,
        appIconFolder: appIconFolder,
        appIconContents: iconMetadata(iconFolder: appIconFolder),
        originalAppIconFolder: originalAppIconFolder,
        originalAppIconContents: iconMetadata(iconFolder: originalAppIconFolder)
    )
}

private func prepareGeneratedAppIconFolder(at path: String, sourceFolder: Folder) throws {
    let fileManager = FileManager.default
    let outputFolderURL = URL(fileURLWithPath: path, isDirectory: true)
    let outputCatalogURL = outputFolderURL.deletingLastPathComponent()

    try fileManager.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)

    let catalogContentsURL = outputCatalogURL.appendingPathComponent("Contents.json")
    if !fileManager.fileExists(atPath: catalogContentsURL.path) {
        let catalogContents = """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """
        try Data(catalogContents.utf8).write(to: catalogContentsURL, options: .atomic)
    }

    let sourceContents = try sourceFolder.file(named: "Contents.json")
    let sourceData = try sourceContents.read()
    let outputContentsURL = outputFolderURL.appendingPathComponent("Contents.json")
    let outputData = try? Data(contentsOf: outputContentsURL)
    if outputData != sourceData {
        try sourceData.write(to: outputContentsURL, options: .atomic)
    }
}

func iconMetadata(iconFolder: Folder) throws -> IconMetadata {
    let contentsFile = try iconFolder.file(named: "Contents.json")
    let jsonData = try contentsFile.read()
    do {
        return try JSONDecoder().decode(IconMetadata.self, from: jsonData)
    } catch {
        throw ScriptError.generalError(message: String(describing: error))
    }
}

func getVersionText(appSetup: AppSetup, designStyle: DesignStyle) throws -> String {
    #if DEBUGGING
        return "1.0 - 20"
    #endif

    let versionNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleShortVersionString", appSetup.infoPlistFile)
    let buildNumberResult = run("/usr/libexec/PlistBuddy", "-c", "Print CFBundleVersion", appSetup.infoPlistFile)

    guard versionNumberResult.succeeded else {
        throw ScriptError.generalError(message: "Unable to read CFBundleShortVersionString from \(appSetup.infoPlistFile): \(versionNumberResult.stderror)")
    }

    guard buildNumberResult.succeeded else {
        throw ScriptError.generalError(message: "Unable to read CFBundleVersion from \(appSetup.infoPlistFile): \(buildNumberResult.stderror)")
    }

    var versionNumber = versionNumberResult.stdout
    if versionNumber == "$(MARKETING_VERSION)" {
        versionNumber = main.env["MARKETING_VERSION"] ?? ""
    }

    var buildNumber = buildNumberResult.stdout
    if buildNumber == "$(CURRENT_PROJECT_VERSION)" {
        buildNumber = main.env["CURRENT_PROJECT_VERSION"] ?? ""
    }

    switch designStyle.versionStyle {
    case .dash:
        return "\(versionNumber) - \(buildNumber)"
    case .parenthesis:
        return "\(versionNumber)(\(buildNumber))"
    case .parenthesisTwoLines:
        return "\(versionNumber)\n(\(buildNumber))"
    case .twoLines:
        return "\(versionNumber)\n\(buildNumber)"
    case .versionOnly:
        return "\(versionNumber)"
    case .buildOnly:
        return "\(buildNumber)"
    case .empty:
        return ""
    }
}

private func resolveInfoPlistPath(
    infoPlistFile: String,
    projectDir: String,
    sourceRootPath: String
) throws -> String {
    if infoPlistFile.hasPrefix("/") {
        return infoPlistFile
    }

    let projectRelativePath = projectDir.appendingPathComponent(path: infoPlistFile)
    if FileManager.default.fileExists(atPath: projectRelativePath) {
        return projectRelativePath
    }

    let sourceRelativePath = sourceRootPath.appendingPathComponent(path: infoPlistFile)
    if FileManager.default.fileExists(atPath: sourceRelativePath) {
        return sourceRelativePath
    }

    throw ScriptError.fileNotFound(message: "Info.plist: \(infoPlistFile)")
}

private func locateAppIconFolder(
    named appIcon: String,
    projectDir: String,
    sourceRootFolder: Folder
) throws -> Folder? {
    let iconFolderName = "\(appIcon).appiconset"

    if let projectFolder = try? Folder(path: projectDir),
       let iconFolder = projectFolder.findFirstFolder(name: iconFolderName) {
        return iconFolder
    }

    return sourceRootFolder.findFirstFolder(name: iconFolderName)
}
