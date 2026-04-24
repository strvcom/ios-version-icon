import Foundation

extension String {
    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }

    func appendingPathComponent(path: String) -> String {
        (self as NSString).appendingPathComponent(path)
    }
}
