import Foundation
import SwiftData

@Model
final class LocalEvent {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var title: String
    var eventDescription: String?
    var startAt: Date
    var endAt: Date
    var isAllDay: Bool

    // Location (Google Maps)
    var locationName: String?
    var locationAddress: String?
    var locationLat: Double?
    var locationLng: Double?
    var locationPlaceID: String?

    // Recurrence
    var recurrenceRuleData: Data? // Encoded RecurrenceRule
    var recurrenceParentID: UUID?
    var recurrenceExceptionDates: [Date]?

    // Alarms (minutes before event)
    var alarms: [Int] // e.g. [10, 30, 60, 1440, 10080]

    // Status
    var status: String // active, cancelled

    // Tags
    var tags: [LocalTag]?

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
        eventDescription: String? = nil,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool = false,
        locationName: String? = nil,
        locationAddress: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        locationPlaceID: String? = nil,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceParentID: UUID? = nil,
        recurrenceExceptionDates: [Date]? = nil,
        alarms: [Int] = [],
        status: String = "active",
        tags: [LocalTag]? = nil,
        syncVersion: Int64 = 1,
        isDeleted: Bool = false,
        syncStatus: String = "pendingUpload",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.eventDescription = eventDescription
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
        self.locationName = locationName
        self.locationAddress = locationAddress
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.locationPlaceID = locationPlaceID
        self.recurrenceRuleData = try? JSONEncoder().encode(recurrenceRule)
        self.recurrenceParentID = recurrenceParentID
        self.recurrenceExceptionDates = recurrenceExceptionDates
        self.alarms = alarms
        self.status = status
        self.tags = tags
        self.syncVersion = syncVersion
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var recurrenceRule: RecurrenceRule? {
        get {
            guard let data = recurrenceRuleData else { return nil }
            return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
        }
        set {
            recurrenceRuleData = try? JSONEncoder().encode(newValue)
        }
    }
}
