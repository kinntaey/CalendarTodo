import CalendarTodoCore
import EventKit
import EventKitUI
import SwiftData
import SwiftUI

extension EKEvent: @retroactive Identifiable {
    public var id: String { eventIdentifier }
}

enum UnifiedEvent: Identifiable {
    case local(LocalEvent)
    case apple(EKEvent)

    var id: String {
        switch self {
        case .local(let e): return e.id.uuidString
        case .apple(let e): return e.eventIdentifier
        }
    }
    var isAllDay: Bool {
        switch self {
        case .local(let e): return e.isAllDay
        case .apple(let e): return e.isAllDay
        }
    }
    var startDate: Date {
        switch self {
        case .local(let e): return e.startAt
        case .apple(let e): return e.startDate
        }
    }
}

struct CalendarContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(AppSettings.self) private var appSettings
    @State private var calendarVM = CalendarViewModel()
    @State private var eventVM = EventViewModel()
    @State private var showEventEdit = false
    @State private var selectedEvent: LocalEvent?
    @State private var selectedAppleEvent: EKEvent?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Minimal header
                    headerView
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                        // Calendar views
                        switch calendarVM.viewMode {
                        case .month:
                            CalendarMonthView(viewModel: calendarVM)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 12)

                            // Events for selected date below calendar
                            selectedDateEventsView
                        case .week:
                            CalendarWeekView(viewModel: calendarVM) { event in
                                selectedEvent = event
                            }
                        case .day:
                            CalendarDayView(viewModel: calendarVM) { event in
                                selectedEvent = event
                            }
                        }
                    }
                    .padding(.bottom, 90) // Space below for tab bar
                }
            .navigationBarHidden(true)
            .sheet(isPresented: $showEventEdit) {
                calendarVM.refreshEvents()
            } content: {
                EventEditView(viewModel: eventVM)
            }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    EventDetailView(
                        event: event,
                        onEdit: {
                            selectedEvent = nil
                            eventVM.loadEvent(event)
                            showEventEdit = true
                        },
                        onDelete: { option in
                            eventVM.setup(modelContext: modelContext)
                            eventVM.deleteRecurringEvent(event, option: option)
                            selectedEvent = nil
                            calendarVM.refreshEvents()
                        }
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedAppleEvent) { appleEvent in
                AppleEventEditView(event: appleEvent) {
                    selectedAppleEvent = nil
                    calendarVM.refreshEvents()
                }
            }
            .onAppear {
                calendarVM.setup(modelContext: modelContext)
                if EventKitService.shared.hasAccess {
                    calendarVM.isAppleCalendarEnabled = true
                    calendarVM.refreshEvents()
                }
                eventVM.setup(modelContext: modelContext)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            // Month & Year
            VStack(alignment: .leading, spacing: 2) {
                Text(DateHelpers.monthName(calendarVM.currentMonth))
                    .font(AppTheme.displayFont)
                    .tracking(-0.5)

                Text(DateHelpers.yearString(calendarVM.currentMonth))
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    calendarVM.goToToday()
                } label: {
                    Text(L10n.today)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(AppTheme.accent.opacity(0.1))
                        )
                }

                Button {
                    eventVM.reset()
                    let now = Date.now
                    let calendar = Calendar.current
                    let hour = calendar.component(.hour, from: now)
                    let selectedDay = calendarVM.selectedDate
                    let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDay) ?? selectedDay
                    let end = start.addingTimeInterval(3600)
                    eventVM.startDate = start
                    eventVM.endDate = end
                    showEventEdit = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accentGradient, in: Circle())
                        .cardShadow()
                }
            }
        }
    }

    // MARK: - Events List

    private var selectedDateEventsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Selected date label
            Text(appSettings.formatDateWithDay(calendarVM.selectedDate))
                .font(AppTheme.titleFont)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            let dayEvents = calendarVM.eventsForDate(calendarVM.selectedDate)
            let appleEvents = calendarVM.appleEventsForDate(calendarVM.selectedDate)

            let allUnified: [UnifiedEvent] = dayEvents.map { .local($0) } + appleEvents.map { .apple($0) }
            let sortedEvents = allUnified.sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.startDate < b.startDate
            }

            if sortedEvents.isEmpty {
                VStack(spacing: 8) {
                    Text(L10n.noEvents)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedEvents) { event in
                        switch event {
                        case .local(let localEvent):
                            Button {
                                selectedEvent = localEvent
                            } label: {
                                SelectedDateEventRow(event: localEvent, displayDate: calendarVM.selectedDate)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        case .apple(let appleEvent):
                            Button {
                                selectedAppleEvent = appleEvent
                            } label: {
                                AppleEventRow(event: appleEvent, displayDate: calendarVM.selectedDate)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Apple Event Row

private struct AppleEventRow: View {
    let event: EKEvent
    var displayDate: Date = .now
    @Environment(AppSettings.self) private var appSettings

    private var eventColor: Color {
        Color(cgColor: event.calendar.cgColor)
    }

    private var isMultiDay: Bool {
        !DateHelpers.isSameDay(event.startDate, event.endDate)
    }

    private var isStartDay: Bool {
        DateHelpers.isSameDay(event.startDate, displayDate)
    }

    private var isEndDay: Bool {
        DateHelpers.isSameDay(event.endDate, displayDate)
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor)
                .frame(width: 4, height: 36)

            // Time column
            if event.isAllDay || (isMultiDay && !isStartDay && !isEndDay) {
                Text(L10n.allDay)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(eventColor)
                    .frame(width: 70, alignment: .leading)
            } else if isMultiDay && isStartDay {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appSettings.formatTime(event.startDate))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1).fixedSize()
                    Text("→ \(appSettings.formatTime(event.endDate))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).fixedSize()
                }
                .frame(width: 70, alignment: .leading)
            } else if isMultiDay && isEndDay {
                VStack(alignment: .leading, spacing: 2) {
                    Text("→ \(appSettings.formatTime(event.endDate))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1).fixedSize()
                    Text(L10n.endTime)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appSettings.formatTime(event.startDate))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1).fixedSize()
                    Text(appSettings.formatTime(event.endDate))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1).fixedSize()
                }
                .frame(width: 70, alignment: .leading)
            }

            // Title + duration
            if isMultiDay {
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title ?? "")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1)

                    let formatter = DateFormatter()
                    let _ = formatter.setLocalizedDateFormatFromTemplate("MMMd HH:mm")
                    let duration = event.endDate.timeIntervalSince(event.startDate)
                    let days = Int(duration / 86400)
                    let hours = Int((duration.truncatingRemainder(dividingBy: 86400)) / 3600)
                    Text("\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate)) (\(days)d \(hours)h)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(event.title ?? "")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }

            Spacer()
        }
        .frame(height: 52)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .fill(eventColor.opacity(0.06))
        )
        .cardShadow()
    }
}

// MARK: - Selected Date Event Row

private struct SelectedDateEventRow: View {
    @Environment(AppSettings.self) private var appSettings
    let event: LocalEvent
    var displayDate: Date = .now

    private var eventColor: Color {
        if let tags = event.tags, let first = tags.first {
            return Color(hex: first.color)
        }
        return AppTheme.accent
    }

    private var isMultiDay: Bool {
        !DateHelpers.isSameDay(event.startAt, event.endAt)
    }

    private var isStartDay: Bool {
        DateHelpers.isSameDay(event.startAt, displayDate)
    }

    private var isEndDay: Bool {
        DateHelpers.isSameDay(event.endAt, displayDate)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor.gradient)
                .frame(width: 4, height: 36)

            // Time column
            if event.isAllDay || (isMultiDay && !isStartDay && !isEndDay) {
                // 종일 이벤트 or 여러 날 이벤트의 중간 날
                Text(L10n.allDay)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(eventColor)
                    .frame(width: 70, alignment: .leading)
            } else if isMultiDay && isStartDay {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appSettings.formatTime(event.startAt))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize()
                    Text("→ \(appSettings.formatTime(event.endAt))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 70, alignment: .leading)
            } else if isMultiDay && isEndDay {
                VStack(alignment: .leading, spacing: 2) {
                    Text("→ \(appSettings.formatTime(event.endAt))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize()
                    Text(L10n.endTime)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, alignment: .leading)
            } else {
                // 당일 이벤트
                VStack(alignment: .leading, spacing: 2) {
                    Text(appSettings.formatTime(event.startAt))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize()
                    Text(appSettings.formatTime(event.endAt))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 70, alignment: .leading)
            }

            // Event title + duration
            if isMultiDay {
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1)

                    let formatter = DateFormatter()
                    let _ = formatter.setLocalizedDateFormatFromTemplate("MMMd HH:mm")
                    let duration = event.endAt.timeIntervalSince(event.startAt)
                    let days = Int(duration / 86400)
                    let hours = Int((duration.truncatingRemainder(dividingBy: 86400)) / 3600)
                    Text("\(formatter.string(from: event.startAt)) - \(formatter.string(from: event.endAt)) (\(days)d \(hours)h)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }

            Spacer()
        }
        .frame(height: 52)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .fill(eventColor.opacity(0.06))
        )
        .cardShadow()
    }
}



// MARK: - Apple Event Edit View

#if canImport(UIKit)
import EventKitUI

struct AppleEventEditView: UIViewControllerRepresentable {
    let event: EKEvent
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let vc = EKEventEditViewController()
        vc.event = event
        vc.eventStore = EKEventStore()
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDismiss()
        }
    }
}
#endif
