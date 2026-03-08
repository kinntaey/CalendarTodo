import Foundation
import SwiftData

@Model
final class LocalTodo {
    @Attribute(.unique) var id: UUID
    var todoListID: UUID?
    var ownerID: UUID
    var title: String
    var todoDescription: String?
    var isCompleted: Bool
    var completedAt: Date?
    var completedBy: UUID?

    // Date assignment
    var assignedDate: Date?
    var dueDate: Date?

    var priority: Int // 0: none, 1: low, 2: medium, 3: high
    var sortOrder: Int

    // Friend assignment
    var assignedTo: UUID?
    var assignmentStatus: String // none, pending, accepted, declined

    // Tags
    var tags: [LocalTag]?

    // Parent list
    @Relationship var todoList: LocalTodoList?

    // Sync
    var syncVersion: Int64
    var isDeleted: Bool
    var syncStatus: String
    var createdAt: Date
    var updatedAt: Date

    init(
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
