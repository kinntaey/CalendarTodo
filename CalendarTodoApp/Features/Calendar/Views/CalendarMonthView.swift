import CalendarTodoCore
import SwiftUI

struct CalendarMonthView: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation header
            HStack {
                Button { viewModel.goToPreviousMonth() } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(DateHelpers.monthYearFormatter.string(from: viewModel.currentMonth))
                    .font(.title2.bold())

                Spacer()

                Button { viewModel.goToNextMonth() } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(viewModel.weekDayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(day == "토" ? .blue : day == "일" ? .red : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            // Calendar grid
            ForEach(Array(viewModel.monthDays.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { index in
                        if let date = week[index] {
                            DayCellView(
                                date: date,
                                isSelected: DateHelpers.isSameDay(date, viewModel.selectedDate),
                                isToday: DateHelpers.isSameDay(date, .now),
                                hasEvents: viewModel.datesWithEvents.contains(
                                    DateHelpers.calendar.dateComponents([.year, .month, .day], from: date)
                                ),
                                events: viewModel.eventsForDate(date)
                            )
                            .onTapGesture {
                                viewModel.selectDate(date)
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
            }
        }
    }
}

private struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let events: [LocalEvent]

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(.blue)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .stroke(.blue, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                Text("\(DateHelpers.dayNumber(date))")
                    .font(.callout)
                    .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)
            }

            // Event dots
            if hasEvents {
                HStack(spacing: 2) {
                    ForEach(0..<min(events.count, 3), id: \.self) { _ in
                        Circle()
                            .fill(.blue)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            } else {
                Spacer()
                    .frame(height: 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}
