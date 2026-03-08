import Foundation
import SwiftData

@Model
public final class LocalEvent {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var title: String
    public var eventDescription: String?
    public var startAt: Date
    public var endAt: Date
    public var isAllDay: Bool

    // Location (Google Maps)
    public var locationName: String?
    public var locationAddress: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var locationPlaceID: String?

    // Recurrence
    public var recurrenceRuleData: Data? // Encoded RecurrenceRule
    public var recurrenceParentID: UUID?
    public var recurrenceExceptionDates: [Date]?

    // Alarms (minutes before event)
    public var alarms: [Int] // e.g. [10, 30, 60, 1440, 10080]

    // Status
    public var status: String // active, cancelled

    // Tags
    public var tags: [LocalTag]?

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

    public var recurrenceRule: RecurrenceRule? {
        get {
            guard let data = recurrenceRuleData else { return nil }
            return try? JSONDecoder().decode(RecurrenceRule.self, from: data)
        }
        set {
            recurrenceRuleData = try? JSONEncoder().encode(newValue)
        }
    }
}
