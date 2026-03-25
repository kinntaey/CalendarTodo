import SwiftUI

struct AlarmPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAlarms: Set<Int>

    private var alarmOptions: [(label: String, minutes: Int)] {
        [
            (L10n.atEventTime, 0),
            (L10n.alarmLabel(minutes: 10), 10),
            (L10n.alarmLabel(minutes: 30), 30),
            (L10n.alarmLabel(minutes: 60), 60),
            (L10n.alarmLabel(minutes: 120), 120),
            (L10n.alarmLabel(minutes: 1440), 1440),
            (L10n.alarmLabel(minutes: 10080), 10080),
            (L10n.alarmLabel(minutes: 20160), 20160),
            (L10n.alarmLabel(minutes: 43200), 43200),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(alarmOptions, id: \.minutes) { option in
                    Button {
                        if selectedAlarms.contains(option.minutes) {
                            selectedAlarms.remove(option.minutes)
                        } else {
                            selectedAlarms.insert(option.minutes)
                        }
                    } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedAlarms.contains(option.minutes) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.selectAlarm)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
