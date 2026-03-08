import CalendarTodoCore
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CalendarViewModel {
    var selectedDate: Date = .now
    var currentMonth: Date = .now
    var viewMode: CalendarViewMode = .month
    var events: [LocalEvent] = []
    var datesWithEvents: Set<DateComponents> = []

    private var eventRepository: EventRepository?

    enum CalendarViewMode: String, CaseIterable {
        case month = "월"
        case week = "주"
        case day = "일"
    }

    func setup(modelContext: ModelContext) {
        eventRepository = EventRepository(modelContext: modelContext)
        refreshEvents()
    }

    func refreshEvents() {
        guard let repo = eventRepository else { return }

        switch viewMode {
        case .month:
            let cal = DateHelpers.calendar
            guard let start = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { return }
            events = repo.fetchEvents(from: start, to: end)
            datesWithEvents = repo.datesWithEvents(in: currentMonth)

        case .week:
            let start = DateHelpers.startOfWeek(for: selectedDate)
            let end = DateHelpers.calendar.date(byAdding: .day, value: 7, to: start) ?? selectedDate
            events = repo.fetchEvents(from: start, to: end)

        case .day:
            events = repo.fetchEvents(for: selectedDate)
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        if viewMode == .month {
            viewMode = .day
        }
        refreshEvents()
    }

    func goToPreviousMonth() {
        currentMonth = DateHelpers.calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        refreshEvents()
    }

    func goToNextMonth() {
        currentMonth = DateHelpers.calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        refreshEvents()
    }

    func goToToday() {
        selectedDate = .now
        currentMonth = .now
        refreshEvents()
    }

    func eventsForDate(_ date: Date) -> [LocalEvent] {
        events.filter { DateHelpers.isSameDay($0.startAt, date) }
    }

    // MARK: - Month Grid

    var monthDays: [[Date?]] {
        let cal = DateHelpers.calendar
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)),
              let range = cal.range(of: .day, in: .month, for: currentMonth) else { return [] }

        let firstWeekday = cal.component(.weekday, from: startOfMonth)
        // Adjust for Monday start (firstWeekday: 2=Mon -> offset 0, 1=Sun -> offset 6)
        let offset = (firstWeekday - cal.firstWeekday + 7) % 7

        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                currentWeek.append(date)
                if currentWeek.count == 7 {
                    weeks.append(currentWeek)
                    currentWeek = []
                }
            }
        }

        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }

        return weeks
    }

    var weekDayHeaders: [String] {
        ["월", "화", "수", "목", "금", "토", "일"]
    }
}
