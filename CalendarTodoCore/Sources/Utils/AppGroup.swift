import Foundation

public enum AppGroup {
    public static let identifier = "group.com.taehee.calendartodo"

    public static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            fatalError("App Group container not found for: \(identifier)")
        }
        return url
    }
}
