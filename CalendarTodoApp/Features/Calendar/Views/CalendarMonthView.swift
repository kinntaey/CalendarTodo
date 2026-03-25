import CalendarTodoCore
import EventKit
import SwiftUI

struct CalendarMonthView: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(Array(viewModel.weekDayHeaders.enumerated()), id: \.offset) { index, day in
                    let isWeekend = index == 5 || index == 6 // 토(5), 일(6) - 월요일 시작 기준
                    Text(day)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isWeekend ? .secondary : .primary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            // Calendar grid with swipe
            TabView(selection: $viewModel.currentMonthIndex) {
                ForEach(-12...12, id: \.self) { offset in
                    monthGrid(for: offset)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: CGFloat(viewModel.monthDays.count) * 82 + 8)
            .onChange(of: viewModel.currentMonthIndex) { _, newValue in
                viewModel.onMonthSwipe(to: newValue)
            }
        }
    }

    private func monthGrid(for offset: Int) -> some View {
        let weeks = offset == 0 ? viewModel.monthDays : viewModel.monthDays(for: offset)
        return VStack(spacing: 0) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { weekIdx, week in
                WeekRowView(
                    week: week,
                    viewModel: viewModel,
                    allEvents: viewModel.events
                )
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Week Row with Multi-Day Event Bars

private struct WeekRowView: View {
    let week: [Date?]
    let viewModel: CalendarViewModel
    let allEvents: [LocalEvent]

    private var weekDates: [Date] {
        week.compactMap { $0 }
    }

    // 통합 multi-day 이벤트 (앱 + Apple)
    private var multiDayItems: [MultiDayItem] {
        guard let firstDate = weekDates.first, let lastDate = weekDates.last else { return [] }
        let cal = DateHelpers.calendar
        let weekStart = cal.startOfDay(for: firstDate)
        let weekEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: lastDate))!

        var items: [MultiDayItem] = []

        // 앱 이벤트
        for event in allEvents where !DateHelpers.isSameDay(event.startAt, event.endAt)
            && event.startAt < weekEnd && event.endAt > weekStart {
            let color: Color = {
                if let tags = event.tags, let first = tags.first { return Color(hex: first.color) }
                return AppTheme.accent
            }()
            items.append(MultiDayItem(id: event.id.uuidString, title: event.title, startDate: event.startAt, endDate: event.endAt, color: color))
        }

        // Apple 이벤트
        for event in viewModel.appleEvents where !DateHelpers.isSameDay(event.startDate, event.endDate)
            && event.startDate < weekEnd && event.endDate > weekStart {
            items.append(MultiDayItem(id: event.eventIdentifier, title: event.title ?? "", startDate: event.startDate, endDate: event.endDate, color: Color(cgColor: event.calendar.cgColor)))
        }

        return items
    }

    private var multiDayEvents: [LocalEvent] {
        guard let firstDate = weekDates.first, let lastDate = weekDates.last else { return [] }
        let cal = DateHelpers.calendar
        let weekStart = cal.startOfDay(for: firstDate)
        let weekEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: lastDate))!

        return allEvents.filter { event in
            !DateHelpers.isSameDay(event.startAt, event.endAt)
            && event.startAt < weekEnd && event.endAt > weekStart
        }
    }

    private var singleDayEvents: [(date: Date, events: [LocalEvent])] {
        weekDates.map { date in
            let dayEvents = viewModel.eventsForDate(date).filter { event in
                DateHelpers.isSameDay(event.startAt, event.endAt)
            }
            return (date: date, events: dayEvents)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day numbers row
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    if let date = week[index] {
                        dayNumberView(date: date)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.selectDate(date)
                                }
                            }
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: 34)
                    }
                }
            }

            // Multi-day event bars (앱 + Apple 통합)
            if !multiDayItems.isEmpty {
                ForEach(multiDayItems.prefix(2), id: \.id) { item in
                    multiDayBarGeneric(item: item)
                }
                Spacer().frame(height: 3)
            }

            // Single-day event indicators
            let multiDayCount = min(multiDayItems.count, 2)
            let singleDayMax = 3 - multiDayCount

            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    if let date = week[index] {
                        let dayEvents = viewModel.eventsForDate(date).filter {
                            DateHelpers.isSameDay($0.startAt, $0.endAt)
                        }
                        let appleEvents = viewModel.appleEventsForDate(date).filter {
                            DateHelpers.isSameDay($0.startDate, $0.endDate)
                        }
                        let totalCount = dayEvents.count + appleEvents.count

                        VStack(spacing: 1) {
                            ForEach(dayEvents.prefix(singleDayMax), id: \.id) { event in
                                EventIndicatorView(event: event)
                            }
                            // Apple 이벤트 (남은 슬롯에)
                            let remaining = singleDayMax - min(dayEvents.count, singleDayMax)
                            ForEach(appleEvents.prefix(remaining), id: \.eventIdentifier) { appleEvent in
                                AppleEventIndicatorView(event: appleEvent)
                            }
                            if totalCount > singleDayMax {
                                Text("+\(totalCount - singleDayMax)")
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectDate(date)
                            }
                        }
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 78)
    }

    // MARK: - Day Number

    private func dayNumberView(date: Date) -> some View {
        let isSelected = DateHelpers.isSameDay(date, viewModel.selectedDate)
        let isToday = DateHelpers.isSameDay(date, .now)
        let weekday = DateHelpers.calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let isHoliday = viewModel.isHoliday(date)

        return Text("\(DateHelpers.dayNumber(date))")
            .font(.system(size: 15, weight: isToday || isSelected ? .bold : .medium, design: .rounded))
            .foregroundStyle(
                isSelected ? .white :
                isToday ? AppTheme.accent :
                isHoliday ? .red :
                isWeekend ? .secondary :
                .primary
            )
            .frame(width: 26, height: 26)
            .background(
                Group {
                    if isSelected {
                        Circle()
                            .fill(AppTheme.accentGradient)
                            .cardShadow()
                    } else if isToday {
                        Circle()
                            .stroke(AppTheme.accent, lineWidth: 1.2)
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.bottom, 1)
    }

    // MARK: - Multi-Day Event Bar (inline)

    private func multiDayBarInline(event: LocalEvent) -> some View {
        let cal = DateHelpers.calendar
        let eventColor: Color = {
            if let tags = event.tags, let first = tags.first {
                return Color(hex: first.color)
            }
            return AppTheme.accent
        }()
        let isStartInWeek = weekDates.contains(where: { DateHelpers.isSameDay($0, event.startAt) })

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                if let date = week[index] {
                    let dayStart = cal.startOfDay(for: date)
                    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                    let isInRange = event.startAt < dayEnd && event.endAt > dayStart
                    // 이번 주에서 이 이벤트가 보이는 첫 번째 셀인지
                    let isFirstVisibleCell: Bool = {
                        if DateHelpers.isSameDay(date, event.startAt) { return true }
                        // 시작일이 이번 주 전이면, 이번 주 첫 번째 유효 날짜에 표시
                        if event.startAt < dayStart {
                            for j in 0..<index {
                                if let d = week[j], event.startAt < cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: d))! && event.endAt > cal.startOfDay(for: d) {
                                    return false // 이전 셀이 이미 첫 번째
                                }
                            }
                            return true
                        }
                        return false
                    }()

                    if isInRange {
                        HStack(spacing: 2) {
                            if isFirstVisibleCell {
                                if isStartInWeek {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(eventColor)
                                        .frame(width: 3, height: 10)
                                } else {
                                    Spacer().frame(width: 3)
                                }
                                Text(event.title)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 14)
                        .background(eventColor.opacity(0.12))
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: 14)
                    }
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: 14)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.horizontal, 2)
    }

    // MARK: - Generic Multi-Day Bar (for both app + Apple events)

    private func multiDayBarGeneric(item: MultiDayItem) -> some View {
        let cal = DateHelpers.calendar
        let isStartInWeek = weekDates.contains(where: { DateHelpers.isSameDay($0, item.startDate) })

        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                if let date = week[index] {
                    let dayStart = cal.startOfDay(for: date)
                    let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                    let isInRange = item.startDate < dayEnd && item.endDate > dayStart
                    let isFirstVisibleCell: Bool = {
                        if DateHelpers.isSameDay(date, item.startDate) { return true }
                        if item.startDate < dayStart {
                            for j in 0..<index {
                                if let d = week[j], item.startDate < cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: d))! && item.endDate > cal.startOfDay(for: d) {
                                    return false
                                }
                            }
                            return true
                        }
                        return false
                    }()

                    if isInRange {
                        HStack(spacing: 2) {
                            if isFirstVisibleCell {
                                if isStartInWeek {
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(item.color)
                                        .frame(width: 3, height: 10)
                                } else {
                                    Spacer().frame(width: 3)
                                }
                                Text(item.title)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 14)
                        .background(item.color.opacity(0.12))
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: 14)
                    }
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: 14)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.horizontal, 2)
    }
}

// MARK: - Multi-Day Item

struct MultiDayItem: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let color: Color
}

// MARK: - Single Day Event Indicator

private struct EventIndicatorView: View {
    let event: LocalEvent

    private var eventColor: Color {
        if let tags = event.tags, let first = tags.first {
            return Color(hex: first.color)
        }
        return AppTheme.accent
    }

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(eventColor)
                .frame(width: 2.5, height: 10)

            Text(event.title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }
}

// MARK: - Apple Event Indicator

private struct AppleEventIndicatorView: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 2.5, height: 10)

            Text(event.title ?? "")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }
}
