import CalendarTodoCore
import SwiftUI

struct CalendarWeekView: View {
    @Bindable var viewModel: CalendarViewModel
    var onEventTap: (LocalEvent) -> Void

    var body: some View {
        let days = DateHelpers.daysInWeek(for: viewModel.selectedDate)

        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(DateHelpers.shortDayName(day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ZStack {
                            if DateHelpers.isSameDay(day, viewModel.selectedDate) {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 28, height: 28)
                            } else if DateHelpers.isSameDay(day, .now) {
                                Circle()
                                    .stroke(.blue, lineWidth: 1.5)
                                    .frame(width: 28, height: 28)
                            }

                            Text("\(DateHelpers.dayNumber(day))")
                                .font(.callout.bold())
                                .foregroundStyle(
                                    DateHelpers.isSameDay(day, viewModel.selectedDate)
                                    ? .white
                                    : DateHelpers.isSameDay(day, .now) ? .blue : .primary
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        viewModel.selectedDate = day
                        viewModel.refreshEvents()
                    }
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Events for selected day
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    let dayEvents = viewModel.eventsForDate(viewModel.selectedDate)

                    if dayEvents.isEmpty {
                        Text("이 날의 일정이 없습니다")
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
    }
}

struct EventRowView: View {
    let event: LocalEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.blue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if event.isAllDay {
                        Text("종일")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(DateHelpers.timeFormatter.string(from: event.startAt)) - \(DateHelpers.timeFormatter.string(from: event.endAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let location = event.locationName, !location.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "mappin")
                            Text(location)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
