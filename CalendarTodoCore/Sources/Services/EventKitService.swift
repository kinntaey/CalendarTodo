import EventKit
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
public final class EventKitService {
    public static let shared = EventKitService()
    private let store = EKEventStore()

    private init() {}

    // MARK: - App Calendar

    private func getOrCreateAppCalendar() -> EKCalendar {
        // 기존 CalendarTodo 캘린더 찾기
        let calendars = store.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == "CalendarTodo" }) {
            return existing
        }

        // 없으면 새로 만들기
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "CalendarTodo"
        #if canImport(UIKit)
        calendar.cgColor = UIColor.systemBlue.cgColor
        #else
        calendar.cgColor = NSColor.systemBlue.cgColor
        #endif

        // iCloud 또는 로컬 소스 찾기
        if let source = store.sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = source
        } else if let source = store.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        }

        try? store.saveCalendar(calendar, commit: true)
        return calendar
    }

    // MARK: - Permission

    public func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            print("[EventKit] Access error: \(error)")
            return false
        }
    }

    public var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    // MARK: - Fetch from Apple Calendar

    public func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return store.events(matching: predicate)
    }

    // MARK: - Add to Apple Calendar

    public func addToAppleCalendar(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        alarms: [Int] // minutes before
    ) -> Bool {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes
        event.calendar = getOrCreateAppCalendar()

        for minutes in alarms {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
        }

        do {
            try store.save(event, span: .thisEvent)
            print("[EventKit] Event saved: \(title)")
            return true
        } catch {
            print("[EventKit] Save error: \(error)")
            return false
        }
    }

    // MARK: - Remove from Apple Calendar

    public func removeFromAppleCalendar(title: String, startDate: Date) -> Bool {
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        let events = fetchEvents(from: startDate, to: endDate)

        for event in events where event.title == title {
            do {
                try store.remove(event, span: .thisEvent)
                print("[EventKit] Event removed: \(title)")
                return true
            } catch {
                print("[EventKit] Remove error: \(error)")
            }
        }
        return false
    }
}
