import CalendarTodoCore
import EventKit
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CalendarViewModel {
    var selectedDate: Date = .now
    var currentMonth: Date = .now
    var currentMonthIndex: Int = 0
    var viewMode: CalendarViewMode = .month
    var events: [LocalEvent] = []
    var appleEvents: [EKEvent] = []
    var expandedOccurrences: [RecurringOccurrence] = []
    var datesWithEvents: Set<DateComponents> = []
    var holidayDates: Set<String> = [] // "yyyy-MM-dd" format
    var isAppleCalendarEnabled = false

    private var eventRepository: EventRepository?
    private var baseMonth: Date = .now

    enum CalendarViewMode: String, CaseIterable {
        case month = "월"
        case week = "주"
        case day = "일"
    }

    func setup(modelContext: ModelContext) {
        eventRepository = EventRepository(modelContext: modelContext)
        baseMonth = currentMonth
        refreshEvents()
    }

    func refreshEvents() {
        guard let repo = eventRepository else { return }

        let rangeStart: Date
        let rangeEnd: Date

        switch viewMode {
        case .month:
            let cal = DateHelpers.calendar
            guard let start = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { return }
            rangeStart = start
            rangeEnd = end

        case .week:
            rangeStart = DateHelpers.startOfWeek(for: selectedDate)
            rangeEnd = DateHelpers.calendar.date(byAdding: .day, value: 7, to: rangeStart) ?? selectedDate

        case .day:
            rangeStart = DateHelpers.calendar.startOfDay(for: selectedDate)
            rangeEnd = DateHelpers.calendar.date(byAdding: .day, value: 1, to: rangeStart) ?? selectedDate
        }

        // Fetch normal events in range
        events = repo.fetchEvents(from: rangeStart, to: rangeEnd)

        // Fetch all recurring events and expand into range
        expandedOccurrences = expandRecurringEvents(repo: repo, rangeStart: rangeStart, rangeEnd: rangeEnd)

        // Fetch Apple Calendar events
        if isAppleCalendarEnabled {
            appleEvents = EventKitService.shared.fetchEvents(from: rangeStart, to: rangeEnd)
        }

        // Update datesWithEvents for month view
        if viewMode == .month {
            var dates = Set<DateComponents>()
            let cal = DateHelpers.calendar
            for event in events {
                dates.insert(cal.dateComponents([.year, .month, .day], from: event.startAt))
            }
            for occ in expandedOccurrences {
                dates.insert(cal.dateComponents([.year, .month, .day], from: occ.startAt))
            }
            for appleEvent in appleEvents {
                dates.insert(cal.dateComponents([.year, .month, .day], from: appleEvent.startDate))
            }
            datesWithEvents = dates

            // 공휴일 감지 (Apple 캘린더에서 "holiday" 타입 캘린더)
            if isAppleCalendarEnabled {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                var holidays = Set<String>()
                for event in appleEvents {
                    if event.calendar.type == .birthday || event.calendar.title.lowercased().contains("holiday") || event.calendar.title.contains("공휴일") || event.calendar.title.contains("휴일") || event.calendar.type == .subscription {
                        if event.isAllDay {
                            holidays.insert(df.string(from: event.startDate))
                        }
                    }
                }
                holidayDates = holidays
            }
        }
    }

    private static let holidayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func isHoliday(_ date: Date) -> Bool {
        holidayDates.contains(Self.holidayFormatter.string(from: date))
    }

    func enableAppleCalendar() {
        Task {
            let granted = await EventKitService.shared.requestAccess()
            isAppleCalendarEnabled = granted
            if granted { refreshEvents() }
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        refreshEvents()
    }

    func onMonthSwipe(to index: Int) {
        guard let newMonth = DateHelpers.calendar.date(byAdding: .month, value: index, to: baseMonth) else { return }
        currentMonth = newMonth
        refreshEvents()
    }

    func goToToday() {
        selectedDate = .now
        currentMonth = .now
        baseMonth = .now
        currentMonthIndex = 0
        refreshEvents()
    }

    func eventsForDate(_ date: Date) -> [LocalEvent] {
        let cal = DateHelpers.calendar
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        // Include events that span across this date (startAt < dayEnd && endAt > dayStart)
        let normalEvents = events.filter { event in
            event.startAt < dayEnd && event.endAt > dayStart
        }
        let recurringEvents = expandedOccurrences
            .filter { DateHelpers.isSameDay($0.startAt, date) }
            .map { $0.parentEvent }

        // Deduplicate
        let normalIDs = Set(normalEvents.map { $0.id })
        let uniqueRecurring = recurringEvents.filter { !normalIDs.contains($0.id) }

        return normalEvents + uniqueRecurring
    }

    func appleEventsForDate(_ date: Date) -> [EKEvent] {
        let cal = DateHelpers.calendar
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

        // 로컬 이벤트 제목+시간으로 중복 제거
        let localEvents = eventsForDate(date)
        let localKeys = Set(localEvents.map { "\($0.title)-\(Int($0.startAt.timeIntervalSince1970))" })

        return appleEvents.filter { event in
            event.startDate < dayEnd && event.endDate > dayStart
            && !localKeys.contains("\(event.title ?? "")-\(Int(event.startDate.timeIntervalSince1970))")
        }
    }

    // MARK: - Recurrence Expansion

    private func expandRecurringEvents(repo: EventRepository, rangeStart: Date, rangeEnd: Date) -> [RecurringOccurrence] {
        // Fetch ALL recurring events (they may start before the range)
        let allEvents = repo.fetchAllRecurringEvents()
        var occurrences: [RecurringOccurrence] = []
        let cal = DateHelpers.calendar

        for event in allEvents {
            guard let rule = event.recurrenceRule else { continue }
            let duration = event.endAt.timeIntervalSince(event.startAt)
            let exceptions = Set(event.recurrenceExceptionDates ?? [])

            let dates = generateOccurrences(
                rule: rule,
                startDate: event.startAt,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                calendar: cal
            )

            for date in dates {
                // Skip the original event date (already in normal events)
                if DateHelpers.isSameDay(date, event.startAt) { continue }
                // Skip exception dates
                if exceptions.contains(where: { DateHelpers.isSameDay($0, date) }) { continue }

                let occStart = date
                let occEnd = occStart.addingTimeInterval(duration)
                occurrences.append(RecurringOccurrence(
                    parentEvent: event,
                    startAt: occStart,
                    endAt: occEnd
                ))
            }
        }

        return occurrences
    }

    private func generateOccurrences(
        rule: RecurrenceRule,
        startDate: Date,
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar
    ) -> [Date] {
        var results: [Date] = []
        var current = startDate
        let maxIterations = 500 // Safety limit
        var count = 0

        // For endDate check
        let ruleEnd = rule.endDate ?? calendar.date(byAdding: .year, value: 2, to: startDate)!

        while current < rangeEnd && current <= ruleEnd && count < maxIterations {
            count += 1

            if rule.frequency == .weekly, let daysOfWeek = rule.daysOfWeek, !daysOfWeek.isEmpty {
                // For weekly with specific days: iterate each day in the week
                let weekStart = DateHelpers.startOfWeek(for: current)
                for dayOffset in 0..<7 {
                    guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                    let weekday = calendar.component(.weekday, from: dayDate)
                    // Convert system weekday (1=Sun) to our format (1=Mon)
                    let ourDay = weekday == 1 ? 7 : weekday - 1
                    if daysOfWeek.contains(ourDay) && dayDate >= startDate && dayDate < rangeEnd && dayDate <= ruleEnd {
                        if dayDate >= rangeStart {
                            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)
                            if let adjusted = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                           minute: timeComponents.minute ?? 0,
                                                           second: timeComponents.second ?? 0,
                                                           of: dayDate) {
                                results.append(adjusted)
                            }
                        }
                    }
                }
                // Jump to next interval
                guard let next = calendar.date(byAdding: .weekOfYear, value: rule.interval, to: weekStart) else { break }
                current = next
            } else {
                // Simple: add current if in range
                if current >= rangeStart && current < rangeEnd {
                    results.append(current)
                }

                // Advance by frequency
                switch rule.frequency {
                case .daily:
                    guard let next = calendar.date(byAdding: .day, value: rule.interval, to: current) else { return results }
                    current = next
                case .weekly:
                    guard let next = calendar.date(byAdding: .weekOfYear, value: rule.interval, to: current) else { return results }
                    current = next
                case .monthly:
                    guard let next = calendar.date(byAdding: .month, value: rule.interval, to: current) else { return results }
                    current = next
                case .yearly:
                    guard let next = calendar.date(byAdding: .year, value: rule.interval, to: current) else { return results }
                    current = next
                }
            }

            // Count limit
            if let maxCount = rule.count, results.count >= maxCount {
                break
            }
        }

        return results
    }

    // MARK: - Month Grid

    var monthDays: [[Date?]] {
        buildMonthDays(for: currentMonth)
    }

    func monthDays(for offset: Int) -> [[Date?]] {
        guard let month = DateHelpers.calendar.date(byAdding: .month, value: offset, to: baseMonth) else { return [] }
        return buildMonthDays(for: month)
    }

    private func buildMonthDays(for month: Date) -> [[Date?]] {
        let cal = DateHelpers.calendar
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let range = cal.range(of: .day, in: .month, for: month) else { return [] }

        let firstWeekday = cal.component(.weekday, from: startOfMonth)
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
        L10n.weekDayHeaders
    }
}

// MARK: - Recurring Occurrence

struct RecurringOccurrence {
    let parentEvent: LocalEvent
    let startAt: Date
    let endAt: Date
}
