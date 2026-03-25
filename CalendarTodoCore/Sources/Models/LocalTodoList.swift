import Foundation
import SwiftData

@Model
public final class LocalTodoList {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var title: String
    public var listType: String // daily, weekly, custom
    public var weekStartDate: Date? // for weekly type
    public var isShared: Bool
    public var isPublic: Bool // true = 친구 공개, false = 나만 보기

    @Relationship(deleteRule: .cascade) public var todos: [LocalTodo]?

    // Sync
    public var syncVersion: Int64
    public var isDeleted: Bool
    public var syncStatus: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        title: String,
        listType: String = "daily",
        weekStartDate: Date? = nil,
        isShared: Bool = false,
        isPublic: Bool = true,
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
        self.isPublic = isPublic
        self.todos = todos
        self.syncVersion = syncVersion
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
