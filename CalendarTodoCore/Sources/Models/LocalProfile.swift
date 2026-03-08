import Foundation
import SwiftData

@Model
public final class LocalProfile {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var username: String
    public var displayName: String
    public var avatarURL: String?
    public var timezone: String
    public var apnsDeviceTokens: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var syncStatus: String // synced, pendingUpload, pendingDelete, conflict

    public init(
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
