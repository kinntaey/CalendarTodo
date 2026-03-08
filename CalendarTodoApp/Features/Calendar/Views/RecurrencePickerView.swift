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

    private let dayNames = [
        (1, "월"), (2, "화"), (3, "수"), (4, "목"),
        (5, "금"), (6, "토"), (7, "일"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Frequency
                Section("반복 주기") {
                    Picker("주기", selection: $frequency) {
                        Text("매일").tag(RecurrenceFrequency.daily)
                        Text("매주").tag(RecurrenceFrequency.weekly)
                        Text("매달").tag(RecurrenceFrequency.monthly)
                        Text("매년").tag(RecurrenceFrequency.yearly)
                    }

                    Stepper("간격: \(interval)", value: $interval, in: 1...99)
                }

                // Day selection (weekly only)
                if frequency == .weekly {
                    Section("요일 선택") {
                        // Preset buttons
                        HStack(spacing: 12) {
                            PresetButton(title: "평일", isActive: selectedDays == [1,2,3,4,5]) {
                                selectedDays = [1, 2, 3, 4, 5]
                            }
                            PresetButton(title: "주말", isActive: selectedDays == [6,7]) {
                                selectedDays = [6, 7]
                            }
                            PresetButton(title: "매일", isActive: selectedDays == [1,2,3,4,5,6,7]) {
                                selectedDays = [1, 2, 3, 4, 5, 6, 7]
                            }
                        }
                        .padding(.vertical, 4)

                        // Individual days
                        HStack(spacing: 8) {
                            ForEach(dayNames, id: \.0) { day, name in
                                DayToggleButton(
                                    name: name,
                                    isSelected: selectedDays.contains(day)
                                ) {
                                    if selectedDays.contains(day) {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                }
                            }
                        }
                    }
                }

                // End date
                Section("종료") {
                    Toggle("종료 날짜 설정", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("종료 날짜", selection: $endDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("반복 규칙")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
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
}

private struct PresetButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? .blue : Color.gray.opacity(0.2), in: Capsule())
                .foregroundStyle(isActive ? .white : .primary)
        }
    }
}

private struct DayToggleButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption.bold())
                .frame(width: 32, height: 32)
                .background(isSelected ? .blue : Color.gray.opacity(0.2), in: Circle())
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}
