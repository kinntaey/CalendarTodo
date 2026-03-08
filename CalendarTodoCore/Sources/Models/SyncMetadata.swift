import Foundation
import SwiftData

enum SyncStatus: String, Codable {
    case synced
    case pendingUpload
    case pendingDelete
    case conflict
}

@Model
final class SyncCursor {
    @Attribute(.unique) var entityType: String // events, todos, todo_lists
    var lastSyncVersion: Int64
    var lastSyncedAt: Date

    init(
        entityType: String,
        lastSyncVersion: Int64 = 0,
        lastSyncedAt: Date = .now
    ) {
        self.entityType = entityType
        self.lastSyncVersion = lastSyncVersion
        self.lastSyncedAt = lastSyncedAt
    }
}
