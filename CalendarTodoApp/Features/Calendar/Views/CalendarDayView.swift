import CalendarTodoCore
import SwiftUI

struct CalendarDayView: View {
    @Bindable var viewModel: CalendarViewModel
    var onEventTap: (LocalEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DateHelpers.dateFormatter.string(from: viewModel.selectedDate))
                        .font(AppTheme.titleFont)

                    if DateHelpers.isSameDay(viewModel.selectedDate, .now) {
                        Text(L10n.today)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                Spacer()

                // Day navigation
                HStack(spacing: 12) {
                    Button {
                        viewModel.selectedDate = DateHelpers.calendar.date(
                            byAdding: .day, value: -1, to: viewModel.selectedDate
                        ) ?? viewModel.selectedDate
                        viewModel.refreshEvents()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.accent.opacity(0.1), in: Circle())
                    }

                    Button {
                        viewModel.selectedDate = DateHelpers.calendar.date(
                            byAdding: .day, value: 1, to: viewModel.selectedDate
                        ) ?? viewModel.selectedDate
                        viewModel.refreshEvents()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.accent.opacity(0.1), in: Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            // Timeline view
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        TimeSlotView(
                            hour: hour,
                            events: eventsForHour(hour),
                            onEventTap: onEventTap
                        )
                    }
                }
            }
        }
        .padding(.bottom, 70)
    }

    private func eventsForHour(_ hour: Int) -> [LocalEvent] {
        let cal = DateHelpers.calendar
        guard let hourStart = cal.date(bySettingHour: hour, minute: 0, second: 0, of: viewModel.selectedDate),
              let hourEnd = cal.date(byAdding: .hour, value: 1, to: hourStart) else { return [] }

        return viewModel.events.filter { event in
            if event.isAllDay { return false }
            return event.startAt < hourEnd && event.endAt > hourStart
        }
    }
}

private struct TimeSlotView: View {
    let hour: Int
    let events: [LocalEvent]
    var onEventTap: (LocalEvent) -> Void

    private var eventColor: Color {
        AppTheme.accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Divider()
                ForEach(events, id: \.id) { event in
                    let color = tagColor(for: event)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.gradient)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            Text(DateHelpers.timeFormatter.string(from: event.startAt))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.smallRadius))
                    .onTapGesture { onEventTap(event) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
        .padding(.horizontal)
    }

    private func tagColor(for event: LocalEvent) -> Color {
        if let tags = event.tags, let first = tags.first {
            return Color(hex: first.color)
        }
        return AppTheme.accent
    }
}
