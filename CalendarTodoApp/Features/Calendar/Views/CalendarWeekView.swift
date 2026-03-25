import CalendarTodoCore
import SwiftUI

struct CalendarWeekView: View {
    @Bindable var viewModel: CalendarViewModel
    var onEventTap: (LocalEvent) -> Void

    var body: some View {
        let days = DateHelpers.daysInWeek(for: viewModel.selectedDate)

        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 6) {
                        Text(DateHelpers.shortDayName(day))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        ZStack {
                            if DateHelpers.isSameDay(day, viewModel.selectedDate) {
                                Circle()
                                    .fill(AppTheme.accentGradient)
                                    .frame(width: 34, height: 34)
                                    .cardShadow()
                            } else if DateHelpers.isSameDay(day, .now) {
                                Circle()
                                    .stroke(AppTheme.accent, lineWidth: 2)
                                    .frame(width: 34, height: 34)
                            }

                            Text("\(DateHelpers.dayNumber(day))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    DateHelpers.isSameDay(day, viewModel.selectedDate)
                                    ? .white
                                    : DateHelpers.isSameDay(day, .now) ? AppTheme.accent : .primary
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedDate = day
                            viewModel.refreshEvents()
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            // Events for selected day
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    let dayEvents = viewModel.eventsForDate(viewModel.selectedDate)

                    if dayEvents.isEmpty {
                        Text(L10n.noEventsForDay)
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(dayEvents, id: \.id) { event in
                            EventRowView(event: event)
                                .onTapGesture { onEventTap(event) }
                        }
                    }
                }
                .padding()
            }
        }
        .padding(.bottom, 70)
    }
}

struct EventRowView: View {
    let event: LocalEvent

    private var eventColor: Color {
        if let tags = event.tags, let first = tags.first {
            return Color(hex: first.color)
        }
        return AppTheme.accent
    }

    var body: some View {
        HStack(spacing: 14) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(eventColor.gradient)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if event.isAllDay {
                        Text(L10n.allDay)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(DateHelpers.timeFormatter.string(from: event.startAt)) - \(DateHelpers.timeFormatter.string(from: event.endAt))")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    if let location = event.locationName, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .fill(eventColor.opacity(0.06))
        )
        .cardShadow()
    }
}
