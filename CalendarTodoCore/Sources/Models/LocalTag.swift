import Foundation
import SwiftData

@Model
final class LocalTag {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var name: String
    var color: String
    var icon: String?
    var createdAt: Date
    var syncStatus: String

    @Relationship(inverse: \LocalEvent.tags) var events: [LocalEvent]?
    @Relationship(inverse: \LocalTodo.tags) var todos: [LocalTodo]?

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        name: String,
        color: String = "#007AFF",
        icon: String? = nil,
        createdAt: Date = .now,
        syncStatus: String = "pendingUpload"
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
        self.syncStatus = syncStatus
    }
}
