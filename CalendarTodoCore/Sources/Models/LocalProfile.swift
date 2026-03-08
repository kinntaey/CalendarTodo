import Foundation
import SwiftData

@Model
final class LocalProfile {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var username: String
    var displayName: String
    var avatarURL: String?
    var timezone: String
    var apnsDeviceTokens: [String]
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: String // synced, pendingUpload, pendingDelete, conflict

    init(
        id: UUID = UUID(),
        username: String,
        displayName: String,
        avatarURL: String? = nil,
        timezone: String = "Asia/Seoul",
        apnsDeviceTokens: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        syncStatus: String = "pendingUpload"
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.timezone = timezone
        self.apnsDeviceTokens = apnsDeviceTokens
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
}
