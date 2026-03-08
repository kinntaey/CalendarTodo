import CalendarTodoCore
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class EventViewModel {
    // Event fields
    var title = ""
    var eventDescription = ""
    var startDate = Date.now
    var endDate = Date.now.addingTimeInterval(3600)
    var isAllDay = false

    // Location
    var locationName = ""
    var locationAddress = ""
    var locationLat: Double?
    var locationLng: Double?
    var locationPlaceID: String?

    // Tags
    var selectedTags: [LocalTag] = []

    // Alarms
    var selectedAlarms: Set<Int> = [] // minutes before

    // Recurrence
    var recurrenceRule: RecurrenceRule?
    var hasRecurrence = false

    // State
    var isEditing = false
    var editingEvent: LocalEvent?
    var isSaving = false
    var errorMessage: String?

    private var eventRepository: EventRepository?

    func setup(modelContext: ModelContext) {
        eventRepository = EventRepository(modelContext: modelContext)
    }

    func loadEvent(_ event: LocalEvent) {
        editingEvent = event
        isEditing = true
        title = event.title
        eventDescription = event.eventDescription ?? ""
        startDate = event.startAt
        endDate = event.endAt
        isAllDay = event.isAllDay
        locationName = event.locationName ?? ""
        locationAddress = event.locationAddress ?? ""
        locationLat = event.locationLat
        locationLng = event.locationLng
        locationPlaceID = event.locationPlaceID
        selectedTags = event.tags ?? []
        selectedAlarms = Set(event.alarms)
        recurrenceRule = event.recurrenceRule
        hasRecurrence = recurrenceRule != nil
    }

    func reset() {
        editingEvent = nil
        isEditing = false
        title = ""
        eventDescription = ""
        startDate = .now
        endDate = Date.now.addingTimeInterval(3600)
        isAllDay = false
        locationName = ""
        locationAddress = ""
        locationLat = nil
        locationLng = nil
        locationPlaceID = nil
        selectedTags = []
        selectedAlarms = []
        recurrenceRule = nil
        hasRecurrence = false
        errorMessage = nil
    }

    func save(ownerID: UUID) -> Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "제목을 입력해주세요."
            return false
        }
        guard endDate > startDate else {
            errorMessage = "종료 시간이 시작 시간보다 이후여야 합니다."
            return false
        }

        guard let repo = eventRepository else { return false }

        if let existing = editingEvent {
            existing.title = title
            existing.eventDescription = eventDescription.isEmpty ? nil : eventDescription
            existing.startAt = startDate
            existing.endAt = endDate
            existing.isAllDay = isAllDay
            existing.locationName = locationName.isEmpty ? nil : locationName
            existing.locationAddress = locationAddress.isEmpty ? nil : locationAddress
            existing.locationLat = locationLat
            existing.locationLng = locationLng
            existing.locationPlaceID = locationPlaceID
            existing.tags = selectedTags
            existing.alarms = Array(selectedAlarms).sorted()
            existing.recurrenceRule = hasRecurrence ? recurrenceRule : nil
            repo.update(existing)
        } else {
            let event = LocalEvent(
                ownerID: ownerID,
                title: title,
                eventDescription: eventDescription.isEmpty ? nil : eventDescription,
                startAt: startDate,
                endAt: endDate,
                isAllDay: isAllDay,
                locationName: locationName.isEmpty ? nil : locationName,
                locationAddress: locationAddress.isEmpty ? nil : locationAddress,
                locationLat: locationLat,
                locationLng: locationLng,
                locationPlaceID: locationPlaceID,
                recurrenceRule: hasRecurrence ? recurrenceRule : nil,
                alarms: Array(selectedAlarms).sorted(),
                tags: selectedTags
            )
            repo.create(event)
        }

        return true
    }

    func deleteEvent() {
        guard let event = editingEvent, let repo = eventRepository else { return }
        repo.softDelete(event)
    }
}
