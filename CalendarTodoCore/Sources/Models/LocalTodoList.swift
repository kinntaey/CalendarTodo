import Foundation
import SwiftData

@Model
final class LocalTodoList {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var title: String
    var listType: String // daily, weekly, custom
    var weekStartDate: Date? // for weekly type
    var isShared: Bool

    @Relationship(deleteRule: .cascade) var todos: [LocalTodo]?

    // Sync
    var syncVersion: Int64
    var isDeleted: Bool
    var syncStatus: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        title: String,
        listType: String = "daily",
        weekStartDate: Date? = nil,
        isShared: Bool = false,
        todos: [LocalTodo]? = nil,
        syncVersion: Int64 = 1,
        isDeleted: Bool = false,
        syncStatus: String = "pendingUpload",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.listType = listType
        self.weekStartDate = weekStartDate
        self.isShared = isShared
        self.todos = todos
        self.syncVersion = syncVersion
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
