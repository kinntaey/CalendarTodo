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
                        .font(.title3.bold())

                    if DateHelpers.isSameDay(viewModel.selectedDate, .now) {
                        Text("오늘")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                // Day navigation
                HStack(spacing: 16) {
                    Button {
                        viewModel.selectedDate = DateHelpers.calendar.date(
                            byAdding: .day, value: -1, to: viewModel.selectedDate
                        ) ?? viewModel.selectedDate
                        viewModel.refreshEvents()
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Button {
                        viewModel.selectedDate = DateHelpers.calendar.date(
                            byAdding: .day, value: 1, to: viewModel.selectedDate
                        ) ?? viewModel.selectedDate
                        viewModel.refreshEvents()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

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

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                Divider()
                ForEach(events, id: \.id) { event in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.blue)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text("\(DateHelpers.timeFormatter.string(from: event.startAt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    .onTapGesture { onEventTap(event) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
        .padding(.horizontal)
    }
}
