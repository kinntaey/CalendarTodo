import Foundation
import SwiftData

@Model
public final class LocalTodo {
    @Attribute(.unique) public var id: UUID
    public var todoListID: UUID?
    public var ownerID: UUID
    public var title: String
    public var todoDescription: String?
    public var isCompleted: Bool
    public var completedAt: Date?
    public var completedBy: UUID?

    // Date assignment
    public var assignedDate: Date?
    public var dueDate: Date?

    public var priority: Int // 0: none, 1: low, 2: medium, 3: high
    public var sortOrder: Int

    // Friend assignment
    public var assignedTo: UUID?
    public var assignmentStatus: String // none, pending, accepted, declined

    // Tags
    public var tags: [LocalTag]?

    // Parent list
    @Relationship public var todoList: LocalTodoList?

    // Sync
    public var syncVersion: Int64
    public var isDeleted: Bool
    public var syncStatus: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        todoListID: UUID? = nil,
        ownerID: UUID,
        title: String,
        todoDescription: String? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        completedBy: UUID? = nil,
        assignedDate: Date? = nil,
        dueDate: Date? = nil,
        priority: Int = 0,
        sortOrder: Int = 0,
        assignedTo: UUID? = nil,
        assignmentStatus: String = "none",
        tags: [LocalTag]? = nil,
        todoList: LocalTodoList? = nil,
        syncVersion: Int64 = 1,
        isDeleted: Bool = false,
        syncStatus: String = "pendingUpload",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.todoListID = todoListID
        self.ownerID = ownerID
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.completedBy = completedBy
        self.assignedDate = assignedDate
        self.dueDate = dueDate
        self.priority = priority
        self.sortOrder = sortOrder
        self.assignedTo = assignedTo
        self.assignmentStatus = assignmentStatus
        self.tags = tags
        self.todoList = todoList
        self.syncVersion = syncVersion
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
