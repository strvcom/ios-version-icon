import AppKit
import Files
import Foundation

enum TitleAlignment: String {
    case left
    case center
    case right
}

enum VersionStyle: String {
    case dash
    case parenthesis
    case parenthesisTwoLines
    case versionOnly
    case buildOnly
    case twoLines
    case empty
}

enum ErrorHandlingMode: String {
    case fail
    case warn
}

struct DesignStyle {
    var ribbon: String?
    var title: String?
    var titleFillColor: NSColor
    var titleStrokeColor: NSColor
    var titleStrokeWidth: Double
    var titleFont: String
    var titleSizeRatio: Double
    var horizontalTitlePositionRatio: Double
    var verticalTitlePositionRatio: Double
    var titleRotation: Double
    var titleAlignment: TitleAlignment
    var versionStyle: VersionStyle
}

struct ScriptSetup {
    var appIcon: String
    var appIconOriginal: String
    var outputAssetCatalog: String?
    var resourcesPath: String
}

struct AppSetup {
    var sourceRootPath: String
    var projectDir: String
    var infoPlistFile: String
    var appIconFolder: Folder
    var appIconContents: IconMetadata
    var originalAppIconFolder: Folder
    var originalAppIconContents: IconMetadata
}
