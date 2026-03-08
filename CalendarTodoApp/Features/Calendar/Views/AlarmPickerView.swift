import SwiftUI

struct AlarmPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAlarms: Set<Int>

    private let alarmOptions: [(label: String, minutes: Int)] = [
        ("이벤트 시간", 0),
        ("10분 전", 10),
        ("30분 전", 30),
        ("1시간 전", 60),
        ("2시간 전", 120),
        ("1일 전", 1440),
        ("1주일 전", 10080),
        ("2주일 전", 20160),
        ("1개월 전", 43200),
    ]

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
            .navigationTitle("알람 선택")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
