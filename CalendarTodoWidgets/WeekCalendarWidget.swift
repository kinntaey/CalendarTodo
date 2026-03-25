import CalendarTodoCore
import EventKit
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Widget

struct WeekCalendarWidget: Widget {
    let kind = "WeekCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekCalendarProvider()) { entry in
            WeekCalendarWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("주간 캘린더 + 할 일")
        .description("이번 주 일정과 오늘 할 일을 한눈에 확인하세요.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Entry

struct WeekCalendarEntry: TimelineEntry {
    let date: Date
    let weekDays: [WeekDayData]
    let multiDayBars: [MultiDayBarData]
    let todos: [TodoWidgetItem]
}

struct WeekDayData: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let dayName: String
    let isToday: Bool
    let isWeekend: Bool
    let events: [EventWidgetItem] // single-day only
}

// MARK: - Provider

struct WeekCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekCalendarEntry {
        WeekCalendarEntry(
            date: .now,
            weekDays: makeSampleWeek(),
            multiDayBars: [],
            todos: [
                TodoWidgetItem(id: UUID(), title: "할 일 예시", isCompleted: false),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekCalendarEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekCalendarEntry>) -> Void) {
        let cal = Calendar.current
        let today = Date.now

        // 이번 주 시작일 (월요일)
        var weekStart = DateHelpers.startOfWeek(for: today)

        // SwiftData에서 데이터 로드
        var weekDays: [WeekDayData] = []
        var multiDayBars: [MultiDayBarData] = []
        var todos: [TodoWidgetItem] = []

        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            storeURL = groupURL.appending(path: "CalendarTodo.store")
        } else {
            storeURL = URL.applicationSupportDirectory.appending(path: "CalendarTodo.store")
        }

        do {
            let schema = Schema([LocalEvent.self, LocalTodo.self, LocalTodoList.self, LocalTag.self, LocalProfile.self, LocalNotification.self, SyncCursor.self])
            let config = ModelConfiguration(schema: schema, url: storeURL, allowsSave: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            let modelContext = ModelContext(container)

            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
            let allEvents: [LocalEvent] = (try? modelContext.fetch(FetchDescriptor<LocalEvent>())) ?? []
            let weekEvents = allEvents.filter { !$0.isDeleted && $0.startAt < weekEnd && $0.endAt >= weekStart }

            // Apple Calendar
            let ekStore = EKEventStore()
            let hasEKAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
            var appleWeekEvents: [EKEvent] = []
            if hasEKAccess {
                let predicate = ekStore.predicateForEvents(withStart: weekStart, end: weekEnd, calendars: nil)
                appleWeekEvents = ekStore.events(matching: predicate)
            }

            // Multi-day bars

            // 앱 multi-day
            for event in weekEvents where !cal.isDate(event.startAt, inSameDayAs: event.endAt) {
                let colorHex = event.tags?.first?.color ?? "#007AFF"
                let startCol = max(0, cal.dateComponents([.day], from: weekStart, to: cal.startOfDay(for: event.startAt)).day ?? 0)
                let endCol = min(6, cal.dateComponents([.day], from: weekStart, to: cal.startOfDay(for: event.endAt)).day ?? 6)
                let startsInWeek = event.startAt >= weekStart
                multiDayBars.append(MultiDayBarData(id: event.id.uuidString, title: event.title, colorHex: colorHex, startCol: max(0, startCol), endCol: max(0, endCol), startsInWeek: startsInWeek))
            }

            // Apple multi-day
            for ae in appleWeekEvents where !cal.isDate(ae.startDate, inSameDayAs: ae.endDate) {
                let startCol = max(0, cal.dateComponents([.day], from: weekStart, to: cal.startOfDay(for: ae.startDate)).day ?? 0)
                let endCol = min(6, cal.dateComponents([.day], from: weekStart, to: cal.startOfDay(for: ae.endDate)).day ?? 6)
                let startsInWeek = ae.startDate >= weekStart
                multiDayBars.append(MultiDayBarData(id: ae.eventIdentifier, title: ae.title ?? "", colorHex: cgColorToHex(ae.calendar.cgColor), startCol: max(0, startCol), endCol: max(0, endCol), startsInWeek: startsInWeek))
            }

            let multiDayCount = min(multiDayBars.count, 2)
            let singleMax = 3 - multiDayCount

            // Per-day single events
            for i in 0..<7 {
                let day = cal.date(byAdding: .day, value: i, to: weekStart)!
                let dayStart = cal.startOfDay(for: day)
                let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
                let weekday = cal.component(.weekday, from: day)

                // 싱글 데이 앱 이벤트
                var dayItems: [EventWidgetItem] = weekEvents
                    .filter { cal.isDate($0.startAt, inSameDayAs: $0.endAt) && $0.startAt < dayEnd && $0.endAt > dayStart }
                    .map { EventWidgetItem(id: $0.id, title: $0.title, startAt: $0.startAt, locationName: $0.locationName, colorHex: $0.tags?.first?.color ?? "#007AFF") }

                // 싱글 데이 Apple 이벤트 (중복 제거)
                let localKeys = Set(dayItems.map { "\($0.title)-\(Int($0.startAt.timeIntervalSince1970))" })
                for ae in appleWeekEvents where cal.isDate(ae.startDate, inSameDayAs: ae.endDate) && ae.startDate < dayEnd && ae.endDate > dayStart {
                    let key = "\(ae.title ?? "")-\(Int(ae.startDate.timeIntervalSince1970))"
                    if !localKeys.contains(key) {
                        dayItems.append(EventWidgetItem(id: UUID(), title: ae.title ?? "", startAt: ae.startDate, locationName: nil, colorHex: cgColorToHex(ae.calendar.cgColor)))
                    }
                }

                let dayNames = ["월", "화", "수", "목", "금", "토", "일"]
                weekDays.append(WeekDayData(
                    date: day,
                    dayNumber: cal.component(.day, from: day),
                    dayName: dayNames[i],
                    isToday: cal.isDateInToday(day),
                    isWeekend: weekday == 1 || weekday == 7,
                    events: Array(dayItems.prefix(singleMax))
                ))
            }

            // 오늘 할 일 (카테고리 이름 포함)
            let todayStart = cal.startOfDay(for: today)
            let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!
            let allTodos: [LocalTodo] = (try? modelContext.fetch(FetchDescriptor<LocalTodo>())) ?? []
            let allLists: [LocalTodoList] = (try? modelContext.fetch(FetchDescriptor<LocalTodoList>())) ?? []
            let listMap = Dictionary(uniqueKeysWithValues: allLists.map { ($0.id, $0.title) })

            todos = allTodos
                .filter { !$0.isDeleted && $0.assignedDate != nil && $0.assignedDate! >= todayStart && $0.assignedDate! < todayEnd }
                .sorted { a, b in
                    if a.isCompleted != b.isCompleted { return !a.isCompleted }
                    return a.sortOrder < b.sortOrder
                }
                .prefix(6)
                .map { TodoWidgetItem(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, categoryName: $0.todoListID.flatMap { listMap[$0] }) }

        } catch {
            print("[Widget] Error: \(error)")
        }

        let entry = WeekCalendarEntry(date: today, weekDays: weekDays, multiDayBars: Array(multiDayBars.prefix(2)), todos: todos)
        let nextUpdate = cal.date(byAdding: .minute, value: 15, to: today)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func cgColorToHex(_ cgColor: CGColor) -> String {
        guard let components = cgColor.components, components.count >= 3 else { return "#007AFF" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func makeSampleWeek() -> [WeekDayData] {
        let cal = Calendar.current
        let start = DateHelpers.startOfWeek(for: .now)
        let dayNames = ["월", "화", "수", "목", "금", "토", "일"]
        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: i, to: start)!
            return WeekDayData(
                date: day,
                dayNumber: cal.component(.day, from: day),
                dayName: dayNames[i],
                isToday: cal.isDateInToday(day),
                isWeekend: false,
                events: []
            )
        }
    }
}

// MARK: - View

struct WeekCalendarWidgetView: View {
    let entry: WeekCalendarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(entry.weekDays) { day in
                    Text(day.dayName)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(day.isWeekend ? .secondary : .primary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 날짜 숫자
            HStack(spacing: 0) {
                ForEach(entry.weekDays) { day in
                    Text("\(day.dayNumber)")
                        .font(.system(size: 14, weight: day.isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(day.isToday ? .white : day.isWeekend ? .secondary : .primary)
                        .frame(width: 26, height: 26)
                        .background {
                            if day.isToday {
                                Circle().fill(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                }
            }

            // Multi-day bars
            ForEach(entry.multiDayBars) { bar in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        if col >= bar.startCol && col <= bar.endCol {
                            HStack(spacing: 2) {
                                if col == bar.startCol && bar.startsInWeek {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color(hex: bar.colorHex))
                                        .frame(width: 2.5, height: 10)
                                }
                                if col == bar.startCol || (col == 0 && !bar.startsInWeek) {
                                    Text(bar.title)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 15)
                            .background(Color(hex: bar.colorHex).opacity(0.12))
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 15)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            // Single-day events
            ForEach(0..<(3 - entry.multiDayBars.count), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(entry.weekDays) { day in
                        if row < day.events.count {
                            HStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color(hex: day.events[row].colorHex))
                                    .frame(width: 2.5, height: 10)

                                Text(day.events[row].title)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 2)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
            }

            // 구분선
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5)
                .padding(.vertical, 2)

            // 오늘 할 일 (카테고리별)
            if entry.todos.isEmpty {
                Text("할 일이 없습니다")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)
            } else {
                let grouped = Dictionary(grouping: entry.todos) { $0.categoryName ?? "" }
                let sortedKeys = grouped.keys.sorted()

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sortedKeys, id: \.self) { category in
                        if !category.isEmpty {
                            Text(category)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(grouped[category] ?? []) { todo in
                            HStack(spacing: 8) {
                                ZStack {
                                    if todo.isCompleted {
                                        Circle()
                                            .fill(.black)
                                            .frame(width: 14, height: 14)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Circle()
                                            .stroke(Color(.systemGray3), lineWidth: 1.5)
                                            .frame(width: 14, height: 14)
                                    }
                                }

                                Text(todo.title)
                                    .font(.system(size: 13, design: .rounded))
                                    .strikethrough(todo.isCompleted)
                                    .foregroundStyle(todo.isCompleted ? .tertiary : .primary)
                                .lineLimit(1)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Color Hex (Widget)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
