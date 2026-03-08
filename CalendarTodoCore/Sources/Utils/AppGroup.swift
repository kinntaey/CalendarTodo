import Foundation

enum AppGroup {
    static let identifier = "group.com.calendartodo.app"

    static var containerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        )!
    }
}
