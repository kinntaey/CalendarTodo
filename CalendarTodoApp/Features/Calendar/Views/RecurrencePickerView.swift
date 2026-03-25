import CalendarTodoCore
import SwiftUI

struct RecurrencePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var rule: RecurrenceRule

    @State private var frequency: RecurrenceFrequency = .weekly
    @State private var interval: Int = 1
    @State private var selectedDays: Set<Int> = []
    @State private var hasEndDate = false
    @State private var endDate = Date.now.addingTimeInterval(86400 * 365)

    private var dayNames: [(Int, String)] {
        let names = L10n.weekDayHeaders
        return Array(zip(1...7, names))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Frequency
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)

                        HStack(spacing: 8) {
                            ForEach(frequencyOptions, id: \.0) { freq, label in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        frequency = freq
                                    }
                                } label: {
                                    Text(label)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(frequency == freq ? Color.black : Color(.systemGray5))
                                        )
                                        .foregroundStyle(frequency == freq ? .white : .primary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider()
                        .padding(.leading, 68)
                        .padding(.trailing, 20)

                    // Interval
                    HStack(spacing: 12) {
                        Image(systemName: "number")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)

                        Text(L10n.interval)
                            .font(.subheadline)

                        Spacer()

                        HStack(spacing: 0) {
                            Button {
                                if interval > 1 { interval -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.subheadline.bold())
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(interval > 1 ? .primary : .tertiary)
                            }

                            Text("\(interval)")
                                .font(.subheadline.bold())
                                .frame(width: 32)
                                .multilineTextAlignment(.center)

                            Button {
                                if interval < 99 { interval += 1 }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.subheadline.bold())
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray5))
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    // Day selection (weekly only)
                    if frequency == .weekly {
                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36)

                                Text(L10n.selectDays)
                                    .font(.subheadline)
                            }

                            // Preset buttons
                            HStack(spacing: 8) {
                                RecurrencePresetChip(
                                    title: L10n.weekdays,
                                    isActive: selectedDays == Set([1, 2, 3, 4, 5])
                                ) {
                                    selectedDays = [1, 2, 3, 4, 5]
                                }
                                RecurrencePresetChip(
                                    title: L10n.weekends,
                                    isActive: selectedDays == Set([6, 7])
                                ) {
                                    selectedDays = [6, 7]
                                }
                                RecurrencePresetChip(
                                    title: L10n.everyday,
                                    isActive: selectedDays == Set(1...7)
                                ) {
                                    selectedDays = Set(1...7)
                                }
                            }
                            .padding(.leading, 48)

                            // Individual day circles
                            HStack(spacing: 8) {
                                ForEach(dayNames, id: \.0) { day, name in
                                    Button {
                                        if selectedDays.contains(day) {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                    } label: {
                                        Text(name)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(selectedDays.contains(day) ? Color.black : Color(.systemGray5))
                                            )
                                            .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                                    }
                                }
                            }
                            .padding(.leading, 48)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }

                    Divider()
                        .padding(.leading, 68)
                        .padding(.trailing, 20)

                    // End date
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)

                        Text(L10n.setEndDate)
                            .font(.subheadline)

                        Spacer()

                        Toggle("", isOn: $hasEndDate)
                            .labelsHidden()
                            .tint(.black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    if hasEndDate {
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle(L10n.recurrenceRule)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        rule = RecurrenceRule(
                            frequency: frequency,
                            interval: interval,
                            daysOfWeek: frequency == .weekly && !selectedDays.isEmpty
                                ? Array(selectedDays).sorted() : nil,
                            endDate: hasEndDate ? endDate : nil
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                frequency = rule.frequency
                interval = rule.interval
                selectedDays = Set(rule.daysOfWeek ?? [])
                hasEndDate = rule.endDate != nil
                if let end = rule.endDate { endDate = end }
            }
        }
        .presentationDetents([.large])
    }

    private var frequencyOptions: [(RecurrenceFrequency, String)] {
        [
            (.daily, L10n.daily),
            (.weekly, L10n.weekly),
            (.monthly, L10n.monthly),
            (.yearly, L10n.yearly),
        ]
    }
}

private struct RecurrencePresetChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? Color.black : Color(.systemGray5))
                )
                .foregroundStyle(isActive ? .white : .primary)
        }
    }
}
