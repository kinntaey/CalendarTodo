import CalendarTodoCore
import SwiftUI

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Bindable var viewModel: EventViewModel
    @State private var showAlarmPicker = false
    @State private var showRecurrencePicker = false
    @State private var showLocationSearch = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // Title & Description
                Section {
                    TextField("제목", text: $viewModel.title)
                        .font(.headline)
                    TextField("설명 (선택)", text: $viewModel.eventDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Date & Time
                Section("시간") {
                    Toggle("종일", isOn: $viewModel.isAllDay)

                    if viewModel.isAllDay {
                        DatePicker("시작", selection: $viewModel.startDate, displayedComponents: .date)
                        DatePicker("종료", selection: $viewModel.endDate, displayedComponents: .date)
                    } else {
                        DatePicker("시작", selection: $viewModel.startDate)
                        DatePicker("종료", selection: $viewModel.endDate)
                    }
                }

                // Location
                Section("위치") {
                    if viewModel.locationName.isEmpty {
                        Button {
                            showLocationSearch = true
                        } label: {
                            Label("위치 추가", systemImage: "mappin.and.ellipse")
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.locationName)
                                    .font(.subheadline)
                                if !viewModel.locationAddress.isEmpty {
                                    Text(viewModel.locationAddress)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                viewModel.locationName = ""
                                viewModel.locationAddress = ""
                                viewModel.locationLat = nil
                                viewModel.locationLng = nil
                                viewModel.locationPlaceID = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Alarm
                Section("알람") {
                    if viewModel.selectedAlarms.isEmpty {
                        Button {
                            showAlarmPicker = true
                        } label: {
                            Label("알람 추가", systemImage: "bell")
                        }
                    } else {
                        ForEach(Array(viewModel.selectedAlarms).sorted(), id: \.self) { minutes in
                            HStack {
                                Text(alarmLabel(minutes: minutes))
                                Spacer()
                                Button {
                                    viewModel.selectedAlarms.remove(minutes)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        Button {
                            showAlarmPicker = true
                        } label: {
                            Label("알람 추가", systemImage: "plus")
                        }
                    }
                }

                // Recurrence
                Section("반복") {
                    Toggle("반복", isOn: $viewModel.hasRecurrence)
                    if viewModel.hasRecurrence {
                        Button {
                            showRecurrencePicker = true
                        } label: {
                            HStack {
                                Text("반복 규칙")
                                Spacer()
                                Text(recurrenceLabel)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Error
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                // Delete
                if viewModel.isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("이벤트 삭제")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "이벤트 수정" : "새 이벤트")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if let userID = authService.currentUser?.id {
                            if viewModel.save(ownerID: userID) {
                                dismiss()
                            }
                        }
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showAlarmPicker) {
                AlarmPickerView(selectedAlarms: $viewModel.selectedAlarms)
            }
            .sheet(isPresented: $showRecurrencePicker) {
                RecurrencePickerView(rule: Binding(
                    get: { viewModel.recurrenceRule ?? .everyWeek },
                    set: { viewModel.recurrenceRule = $0 }
                ))
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(
                    locationName: $viewModel.locationName,
                    locationAddress: $viewModel.locationAddress,
                    locationLat: $viewModel.locationLat,
                    locationLng: $viewModel.locationLng,
                    locationPlaceID: $viewModel.locationPlaceID
                )
            }
            .alert("이벤트를 삭제하시겠습니까?", isPresented: $showDeleteConfirm) {
                Button("삭제", role: .destructive) {
                    viewModel.deleteEvent()
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            }
        }
    }

    private var recurrenceLabel: String {
        guard let rule = viewModel.recurrenceRule else { return "선택" }
        switch rule.frequency {
        case .daily: return "매일"
        case .weekly:
            if let days = rule.daysOfWeek {
                let names = days.sorted().compactMap { dayName($0) }
                return "매주 " + names.joined(separator: ", ")
            }
            return "매주"
        case .monthly: return "매달"
        case .yearly: return "매년"
        }
    }

    private func dayName(_ day: Int) -> String? {
        switch day {
        case 1: "월"
        case 2: "화"
        case 3: "수"
        case 4: "목"
        case 5: "금"
        case 6: "토"
        case 7: "일"
        default: nil
        }
    }

    private func alarmLabel(minutes: Int) -> String {
        switch minutes {
        case 0: "이벤트 시간"
        case 10: "10분 전"
        case 30: "30분 전"
        case 60: "1시간 전"
        case 120: "2시간 전"
        case 1440: "1일 전"
        case 10080: "1주일 전"
        case 20160: "2주일 전"
        case 43200: "1개월 전"
        default: "\(minutes)분 전"
        }
    }
}
