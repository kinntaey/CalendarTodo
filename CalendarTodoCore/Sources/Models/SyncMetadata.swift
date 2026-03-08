import Foundation
import SwiftData

public enum SyncStatus: String, Codable {
    case synced
    case pendingUpload
    case pendingDelete
    case conflict
}

@Model
public final class SyncCursor {
    @Attribute(.unique) public var entityType: String // events, todos, todo_lists
    public var lastSyncVersion: Int64
    public var lastSyncedAt: Date

    public init(
        entityType: String,
        lastSyncVersion: Int64 = 0,
        lastSyncedAt: Date = .now
    ) {
        self.entityType = entityType
        self.lastSyncVersion = lastSyncVersion
        self.lastSyncedAt = lastSyncedAt
    }
}
