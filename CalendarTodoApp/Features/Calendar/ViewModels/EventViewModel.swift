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

    // Color
    var selectedColor: String = "#007AFF"

    // Tags
    var selectedTags: [LocalTag] = []

    // Alarms
    var selectedAlarms: Set<Int> = [] // minutes before

    // Recurrence
    var recurrenceRule: RecurrenceRule?
    var hasRecurrence = false

    // Friends invitation
    var invitedFriendIDs: [UUID] = []
    var friends: [FriendshipWithProfile] = []

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
        selectedColor = event.tags?.first?.color ?? "#007AFF"
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
        selectedColor = "#007AFF"
        selectedTags = []
        selectedAlarms = []
        recurrenceRule = nil
        hasRecurrence = false
        invitedFriendIDs = []
        errorMessage = nil
    }

    func loadFriends() {
        Task {
            do {
                friends = try await FriendshipService().fetchFriends()
            } catch {
                print("[EventVM] Failed to load friends: \(error)")
            }
        }
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

        // Update or create color tag
        let colorTag: LocalTag
        if let existingTag = selectedTags.first {
            existingTag.color = selectedColor
            colorTag = existingTag
        } else {
            colorTag = LocalTag(ownerID: ownerID, name: "", color: selectedColor)
        }

        if let existing = editingEvent {
            let timeChanged = existing.startAt != startDate || existing.endAt != endDate
            let locationChanged = existing.locationName != (locationName.isEmpty ? nil : locationName)

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
            existing.tags = [colorTag]
            existing.alarms = Array(selectedAlarms).sorted()
            existing.recurrenceRule = hasRecurrence ? recurrenceRule : nil
            repo.update(existing)

            // 시간/위치 변경 시 참여자에게 알림
            if timeChanged || locationChanged {
                Task {
                    await notifyParticipantsOfChange(
                        eventTitle: title,
                        ownerID: ownerID,
                        timeChanged: timeChanged,
                        locationChanged: locationChanged,
                        newStart: startDate,
                        newEnd: endDate,
                        newLocation: locationName
                    )
                }
            }
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
                tags: [colorTag]
            )
            repo.create(event)
        }

        // 로컬 알람 예약
        scheduleLocalAlarms(title: title, startDate: startDate, alarms: Array(selectedAlarms).sorted())

        // Apple Calendar에도 저장
        if EventKitService.shared.hasAccess {
            _ = EventKitService.shared.addToAppleCalendar(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: locationName.isEmpty ? nil : locationName,
                notes: eventDescription.isEmpty ? nil : eventDescription,
                alarms: Array(selectedAlarms).sorted()
            )
        }

        // 친구 초대가 있으면 Supabase에 이벤트 올리고 초대 전송
        if !invitedFriendIDs.isEmpty {
            Task {
                await sendInvitations(ownerID: ownerID)
            }
        }

        return true
    }

    private func sendInvitations(ownerID: UUID) async {
        do {
            let supabase = SupabaseService.shared.client
            let ownerStr = ownerID.uuidString.lowercased()

            // Supabase에 이벤트 생성
            struct EventInsert: Encodable {
                let owner_id: String
                let title: String
                let description: String?
                let start_at: Date
                let end_at: Date
                let is_all_day: Bool
                let location_name: String?
                let location_address: String?
                let alarms: [Int]
                let color: String
            }

            struct EventResult: Decodable {
                let id: UUID
            }

            let result: EventResult = try await supabase
                .from("events")
                .insert(EventInsert(
                    owner_id: ownerStr,
                    title: title,
                    description: eventDescription.isEmpty ? nil : eventDescription,
                    start_at: startDate,
                    end_at: endDate,
                    is_all_day: isAllDay,
                    location_name: locationName.isEmpty ? nil : locationName,
                    location_address: locationAddress.isEmpty ? nil : locationAddress,
                    alarms: Array(selectedAlarms).sorted(),
                    color: selectedColor
                ))
                .select("id")
                .single()
                .execute()
                .value

            // 초대 전송
            try await EventParticipantService().inviteFriends(
                eventID: result.id,
                friendIDs: invitedFriendIDs
            )

            print("[Event] Invitations sent to \(invitedFriendIDs.count) friends")
        } catch {
            print("[Event] Invitation error: \(error)")
        }
    }

    private func notifyParticipantsOfChange(
        eventTitle: String,
        ownerID: UUID,
        timeChanged: Bool,
        locationChanged: Bool,
        newStart: Date,
        newEnd: Date,
        newLocation: String
    ) async {
        do {
            let supabase = SupabaseService.shared.client
            let ownerStr = ownerID.uuidString.lowercased()

            // Supabase에서 이벤트 업데이트
            struct EventUpdate: Encodable {
                let title: String
                let start_at: Date
                let end_at: Date
                let location_name: String?
            }

            try await supabase
                .from("events")
                .update(EventUpdate(
                    title: eventTitle,
                    start_at: newStart,
                    end_at: newEnd,
                    location_name: newLocation.isEmpty ? nil : newLocation
                ))
                .eq("owner_id", value: ownerStr)
                .eq("title", value: eventTitle)
                .execute()

            // 참가자 목록 가져오기
            let participants = try await EventParticipantService().fetchParticipantsForTitle(eventTitle)

            let ownerProfile: ProfileResponse = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: ownerStr)
                .single()
                .execute()
                .value

            // 변경 내용 메시지 생성
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("MMMd HH:mm")
            var changeMsg = "'\(eventTitle)' "
            if timeChanged {
                changeMsg += formatter.string(from: newStart)
            }
            if locationChanged && !newLocation.isEmpty {
                if timeChanged { changeMsg += ", " }
                changeMsg += newLocation
            }

            struct PushPayload: Encodable {
                let recipient_id: String
                let title: String
                let body: String
            }

            for p in participants where p.status != "owner" && p.profile.id != ownerID {
                // 참여자의 복제된 이벤트도 업데이트
                try? await supabase
                    .from("events")
                    .update(EventUpdate(
                        title: eventTitle,
                        start_at: newStart,
                        end_at: newEnd,
                        location_name: newLocation.isEmpty ? nil : newLocation
                    ))
                    .eq("owner_id", value: p.profile.id.uuidString.lowercased())
                    .eq("title", value: eventTitle)
                    .execute()

                // 푸시 알림
                try? await supabase.functions.invoke(
                    "send-push-notification",
                    options: .init(body: PushPayload(
                        recipient_id: p.profile.id.uuidString.lowercased(),
                        title: "CalendarTodo",
                        body: "@\(ownerProfile.username) updated: \(changeMsg)"
                    ))
                )
            }

            print("[Event] Updated & notified \(participants.count - 1) participants")
        } catch {
            print("[Event] Notify change error: \(error)")
        }
    }

    private func scheduleLocalAlarms(title: String, startDate: Date, alarms: [Int]) {
        let center = UNUserNotificationCenter.current()
        // 기존 같은 제목 알람 제거
        center.removePendingNotificationRequests(withIdentifiers: alarms.map { "alarm-\(title)-\($0)" })

        for minutes in alarms {
            let triggerDate = startDate.addingTimeInterval(TimeInterval(-minutes * 60))
            guard triggerDate > Date.now else { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = L10n.alarmLabel(minutes: minutes)
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(identifier: "alarm-\(title)-\(minutes)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    func deleteEvent() {
        guard let event = editingEvent, let repo = eventRepository else { return }
        repo.softDelete(event)
    }

    func deleteRecurringEvent(_ event: LocalEvent, option: RecurringDeleteOption?) {
        guard let repo = eventRepository else { return }

        guard let option = option else {
            // Non-recurring: just delete
            repo.softDelete(event)
            return
        }

        switch option {
        case .thisOnly:
            // Add this date to exception dates
            var exceptions = event.recurrenceExceptionDates ?? []
            exceptions.append(event.startAt)
            event.recurrenceExceptionDates = exceptions
            repo.update(event)

        case .thisAndFuture:
            // Set the recurrence end date to this event's date
            if var rule = event.recurrenceRule {
                rule.endDate = Calendar.current.date(byAdding: .day, value: -1, to: event.startAt)
                event.recurrenceRule = rule
                repo.update(event)
            }

        case .all:
            repo.softDelete(event)
        }
    }
}
