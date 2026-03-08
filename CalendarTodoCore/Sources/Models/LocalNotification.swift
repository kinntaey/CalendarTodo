import Foundation
import SwiftData

@Model
final class LocalNotification {
    @Attribute(.unique) var id: UUID
    var recipientID: UUID
    var senderID: UUID?
    var type: String
    // friend_request, friend_accepted, event_invitation, event_response,
    // todo_assigned, todo_assignment_response, todo_list_invitation,
    // todo_list_response, todo_completed, event_alarm

    var referenceType: String? // event, todo, todo_list, friendship
    var referenceID: UUID?
    var title: String
    var body: String?
    var isRead: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        recipientID: UUID,
        senderID: UUID? = nil,
        type: String,
        referenceType: String? = nil,
        referenceID: UUID? = nil,
        title: String,
        body: String? = nil,
        isRead: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.recipientID = recipientID
        self.senderID = senderID
        self.type = type
        self.referenceType = referenceType
        self.referenceID = referenceID
        self.title = title
        self.body = body
        self.isRead = isRead
        self.createdAt = createdAt
    }
}
