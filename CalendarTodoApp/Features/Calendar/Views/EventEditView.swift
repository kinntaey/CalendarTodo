import CalendarTodoCore
import SwiftUI

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @Environment(AppSettings.self) private var appSettings
    @Bindable var viewModel: EventViewModel
    @State private var showAlarmPicker = false
    @State private var showRecurrencePicker = false
    @State private var showLocationSearch = false
    @State private var showDeleteConfirm = false
    @State private var showDatePicker = false
    @State private var editingStart = true
    @State private var showFriendPicker = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title with color accent bar
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: viewModel.selectedColor))
                                .frame(width: 4, height: 32)

                            TextField(L10n.title, text: $viewModel.title)
                                .font(.title2)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 20)

                        // Color picker
                        ScheduleColorPicker(selectedColor: $viewModel.selectedColor)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // Date & Time row
                        HStack(alignment: .center, spacing: 0) {
                            Image(systemName: "clock")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36)

                            dateBlock(date: viewModel.startDate, showTime: !viewModel.isAllDay, isActive: showDatePicker && editingStart)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if showDatePicker && editingStart {
                                            showDatePicker = false
                                        } else {
                                            editingStart = true
                                            showDatePicker = true
                                        }
                                    }
                                }

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)

                            dateBlock(date: viewModel.endDate, showTime: !viewModel.isAllDay, isActive: showDatePicker && !editingStart)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if showDatePicker && !editingStart {
                                            showDatePicker = false
                                        } else {
                                            editingStart = false
                                            showDatePicker = true
                                        }
                                    }
                                }

                            Spacer()

                            // AllDay pill button
                            Button {
                                viewModel.isAllDay.toggle()
                            } label: {
                                Text(L10n.allDay)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(viewModel.isAllDay ? .white : .secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(viewModel.isAllDay ? Color.blue : Color(.systemGray5))
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        // Inline wheel date picker
                        if showDatePicker {
                            VStack(spacing: 20) {
                                DatePicker("", selection: editingStart ? $viewModel.startDate : $viewModel.endDate,
                                           displayedComponents: viewModel.isAllDay ? .date : [.date, .hourAndMinute])
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .scaleEffect(0.85)
                                    .frame(maxHeight: 140)
                                    .onChange(of: viewModel.startDate) { oldStart, newStart in
                                        if editingStart {
                                            // 기존 duration 유지
                                            let duration = viewModel.endDate.timeIntervalSince(oldStart)
                                            let safeDuration = duration > 0 ? duration : 3600
                                            viewModel.endDate = newStart.addingTimeInterval(safeDuration)
                                        }
                                    }

                                // Duration quick buttons
                                if !viewModel.isAllDay {
                                    HStack(spacing: 12) {
                                        ForEach([0, 30, 60], id: \.self) { minutes in
                                            let label = minutes == 0 ? "0min." : "\(minutes)min."
                                            let isSelected: Bool = {
                                                let diff = Int(viewModel.endDate.timeIntervalSince(viewModel.startDate) / 60)
                                                return diff == minutes
                                            }()
                                            Button {
                                                viewModel.endDate = viewModel.startDate.addingTimeInterval(Double(minutes) * 60)
                                            } label: {
                                                Text(label)
                                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .stroke(isSelected ? Color.primary : Color(.systemGray4), lineWidth: 1.5)
                                                    )
                                                    .foregroundStyle(isSelected ? .primary : .secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }

                        // Recurrence row
                        Button {
                            if viewModel.hasRecurrence {
                                showRecurrencePicker = true
                            } else {
                                viewModel.hasRecurrence = true
                                showRecurrencePicker = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.trianglehead.2.clockwise")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36)

                                Text(viewModel.hasRecurrence ? recurrenceLabel : L10n.doesNotRepeat)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 20)

                        // Alarm row
                        VStack(alignment: .leading, spacing: 0) {
                            if viewModel.selectedAlarms.isEmpty {
                                Button {
                                    showAlarmPicker = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "bell")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 36)

                                        Text(L10n.addAlarm)
                                            .font(.subheadline)
                                            .foregroundStyle(Color(.placeholderText))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)
                            } else {
                                ForEach(Array(viewModel.selectedAlarms).sorted(), id: \.self) { minutes in
                                    HStack(spacing: 12) {
                                        Image(systemName: "bell.fill")
                                            .font(.title3)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 36)

                                        Text(L10n.alarmLabel(minutes: minutes))
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color(.systemGray5))
                                            )

                                        Spacer()

                                        Button {
                                            viewModel.selectedAlarms.remove(minutes)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                }

                                Button {
                                    showAlarmPicker = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Spacer().frame(width: 36)
                                        Image(systemName: "plus")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text(L10n.addAlarm)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                }
                            }
                        }

                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 20)

                        // Location row
                        if viewModel.locationName.isEmpty {
                            Button {
                                showLocationSearch = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36)

                                    Text(L10n.locationSection)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(.placeholderText))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .frame(width: 36)

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
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }

                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 20)

                        // Invite friends row
                        Button {
                            showFriendPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36)

                                if viewModel.invitedFriendIDs.isEmpty {
                                    Text(L10n.inviteFriends)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                } else {
                                    // Show invited friend avatars
                                    HStack(spacing: -6) {
                                        ForEach(viewModel.friends.filter { viewModel.invitedFriendIDs.contains($0.profile.id) }) { friend in
                                            ProfileAvatar(name: friend.profile.displayName, size: 28)
                                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                        }
                                    }

                                    Text("\(viewModel.invitedFriendIDs.count)")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 68)
                            .padding(.trailing, 20)

                        // Description row
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36)
                                .padding(.top, 2)

                            TextField(L10n.descriptionOptional, text: $viewModel.eventDescription, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(3...8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        // Error
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }

                        // Delete
                        if viewModel.isEditing {
                            Divider()
                                .padding(.leading, 68)
                                .padding(.trailing, 20)

                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash")
                                        .font(.title3)
                                        .frame(width: 36)

                                    Text(L10n.deleteEvent)
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            }
                        }

                        Spacer().frame(height: 100)
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                // Floating Save button
                Button {
                    let userID = authService.currentUser?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                    if viewModel.save(ownerID: userID) {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                        Text(L10n.save)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(.black))
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationTitle(viewModel.isEditing ? L10n.editEvent : L10n.newEvent)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
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
            .sheet(isPresented: $showFriendPicker) {
                FriendPickerSheet(
                    selectedFriendIDs: $viewModel.invitedFriendIDs,
                    friends: viewModel.friends
                )
            }
            .onAppear {
                viewModel.loadFriends()
            }
            .alert(L10n.deleteEventConfirm, isPresented: $showDeleteConfirm) {
                Button(L10n.delete, role: .destructive) {
                    viewModel.deleteEvent()
                    dismiss()
                }
                Button(L10n.cancel, role: .cancel) {}
            }
            .environment(\.locale, DateHelpers.preferredLocale)
        }
    }

    // MARK: - Date block (date + bold time)

    private func dateBlock(date: Date, showTime: Bool, isActive: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(shortDateString(date))
                .font(.subheadline)
                .foregroundStyle(isActive ? .primary : .secondary)

            if showTime {
                Text(appSettings.formatTime(date))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
        }
    }

    private func shortDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = DateHelpers.preferredLocale
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f.string(from: date)
    }

    // MARK: - Recurrence label

    private var recurrenceLabel: String {
        guard let rule = viewModel.recurrenceRule else { return L10n.doesNotRepeat }
        switch rule.frequency {
        case .daily: return L10n.daily
        case .weekly:
            if let days = rule.daysOfWeek {
                let names = days.sorted().compactMap { dayName($0) }
                return L10n.weekly + " " + names.joined(separator: ", ")
            }
            return L10n.weekly
        case .monthly: return L10n.monthly
        case .yearly: return L10n.yearly
        }
    }

    private func dayName(_ day: Int) -> String? {
        let names = L10n.weekDayHeaders
        guard (1...7).contains(day) else { return nil }
        return names[day - 1]
    }
}

// MARK: - Schedule Color Picker

private struct ScheduleColorPicker: View {
    @Binding var selectedColor: String

    private let colors: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Green", "#34C759"),
        ("Teal", "#5AC8FA"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Brown", "#A2845E"),
        ("Gray", "#8E8E93"),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(colors, id: \.hex) { color in
                Circle()
                    .fill(Color(hex: color.hex))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .padding(1)
                            .opacity(selectedColor == color.hex ? 1 : 0)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(hex: color.hex), lineWidth: 2)
                            .padding(-1)
                            .opacity(selectedColor == color.hex ? 1 : 0)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedColor = color.hex
                        }
                    }
            }
        }
    }
}
