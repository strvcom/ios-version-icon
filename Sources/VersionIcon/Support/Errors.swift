import Foundation
import Moderator

protocol PrintableError {
    var errorDescription: String { get }
}

enum ScriptError: Error {
    case generalError(message: String)
    case fileExists(message: String)
    case fileNotFound(message: String)
    case folderExists(message: String)
    case folderNotFound(message: String)
    case argumentError(message: String)
    case moreInfoNeeded(message: String)
    case renameFailed(message: String)
}

extension ScriptError: PrintableError {
    var errorDescription: String {
        let prefix = "💥 error: "

        switch self {
        case let .generalError(message):
            return prefix + message
        case let .fileExists(message):
            return prefix + "file exists: \(message)"
        case let .fileNotFound(message):
            return prefix + "file not found: \(message)"
        case let .folderExists(message):
            return prefix + "folder exists: \(message)"
        case let .folderNotFound(message):
            return prefix + "folder not found: \(message)"
        case let .argumentError(message):
            return prefix + "invalid argument: \(message)"
        case let .moreInfoNeeded(message):
            return prefix + "more info needed: \(message)"
        case let .renameFailed(message):
            return prefix + "rename failed: \(message)"
        }
    }
}

extension ArgumentError: PrintableError {
    var errorDescription: String {
        "💥 error: \(errormessage)"
    }
}
