import Foundation
import SwiftData

@Model
public final class LocalTag {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var name: String
    public var color: String
    public var icon: String?
    public var createdAt: Date
    public var syncStatus: String

    @Relationship(inverse: \LocalEvent.tags) public var events: [LocalEvent]?
    @Relationship(inverse: \LocalTodo.tags) public var todos: [LocalTodo]?

    public init(
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
