import CalendarTodoCore
import SwiftUI

struct TodoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let todo: LocalTodo
    let onSave: () -> Void

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: Int = 0
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool = false
    @State private var recurrenceRule: RecurrenceRule?
    @State private var showDeleteConfirm = false
    @State private var showFriendPicker = false
    @State private var friends: [FriendshipWithProfile] = []
    @State private var assignToFriendID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(priorityAccentColor)
                            .frame(width: 4, height: 32)

                        TextField(L10n.title, text: $title)
                            .font(.title2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // Priority
                    HStack(spacing: 12) {
                        Image(systemName: "flag")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)

                        HStack(spacing: 8) {
                            ForEach(0...3, id: \.self) { p in
                                Button {
                                    priority = p
                                } label: {
                                    Text(priorityLabel(p))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(priority == p ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule().fill(priority == p ? priorityColor(p) : Color(.systemGray5))
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider().padding(.leading, 68).padding(.trailing, 20)

                    // Due date
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)

                        Toggle(L10n.dueDate, isOn: $hasDueDate)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    if hasDueDate {
                        DatePicker("", selection: Binding(
                            get: { dueDate ?? .now },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 68)
                            .padding(.bottom, 12)
                    }

                    Divider().padding(.leading, 68).padding(.trailing, 20)

                    // Recurrence
                    HStack(spacing: 12) {
                        Image(systemName: "repeat")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)

                        Menu {
                            Button {
                                recurrenceRule = nil
                            } label: {
                                Label(L10n.doesNotRepeat, systemImage: recurrenceRule == nil ? "checkmark" : "")
                            }
                            Button {
                                recurrenceRule = RecurrenceRule(frequency: .daily, interval: 1)
                            } label: {
                                Label(L10n.daily, systemImage: recurrenceRule?.frequency == .daily ? "checkmark" : "")
                            }
                            Button {
                                recurrenceRule = RecurrenceRule(frequency: .weekly, interval: 1)
                            } label: {
                                Label(L10n.weekly, systemImage: recurrenceRule?.frequency == .weekly ? "checkmark" : "")
                            }
                            Button {
                                recurrenceRule = .weekdays
                            } label: {
                                Label(L10n.weekdays, systemImage: recurrenceRule?.daysOfWeek == [1,2,3,4,5] ? "checkmark" : "")
                            }
                            Button {
                                recurrenceRule = RecurrenceRule(frequency: .monthly, interval: 1)
                            } label: {
                                Label(L10n.monthly, systemImage: recurrenceRule?.frequency == .monthly ? "checkmark" : "")
                            }
                        } label: {
                            Text(todoRecurrenceLabel)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    Divider().padding(.leading, 68).padding(.trailing, 20)

                    // Assign to friend
                    Button {
                        showFriendPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                                .foregroundStyle(.blue.opacity(0.7))
                                .frame(width: 36)

                            if let friendID = assignToFriendID,
                               let friend = friends.first(where: { $0.profile.id == friendID }) {
                                HStack(spacing: 8) {
                                    ProfileAvatar(name: friend.profile.displayName, size: 24)
                                    Text(friend.profile.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                Text(L10n.assignToFriend)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 68).padding(.trailing, 20)

                    // Description
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "text.alignleft")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                            .padding(.top, 2)

                        TextField(L10n.descriptionOptional, text: $description, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(3...8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 68).padding(.trailing, 20)

                    // Delete
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.title3)
                                .frame(width: 36)
                            Text(L10n.deleteTodo)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(L10n.editTodo)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        saveTodo()
                    }
                    .bold()
                }
            }
            .alert(L10n.deleteTodoConfirm, isPresented: $showDeleteConfirm) {
                Button(L10n.delete, role: .destructive) {
                    let repo = TodoRepository(modelContext: modelContext)
                    repo.softDelete(todo)
                    onSave()
                    dismiss()
                }
                Button(L10n.cancel, role: .cancel) {}
            }
            .sheet(isPresented: $showFriendPicker) {
                FriendSinglePickerSheet(
                    selectedFriendID: $assignToFriendID,
                    friends: friends
                )
            }
            .onAppear {
                title = todo.title
                description = todo.todoDescription ?? ""
                priority = todo.priority
                dueDate = todo.dueDate
                hasDueDate = todo.dueDate != nil
                recurrenceRule = todo.recurrenceRule
                assignToFriendID = todo.assignedTo
                Task {
                    friends = (try? await FriendshipService().fetchFriends()) ?? []
                }
            }
            .environment(\.locale, DateHelpers.preferredLocale)
        }
    }

    private func saveTodo() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let repo = TodoRepository(modelContext: modelContext)
        todo.title = trimmed
        todo.todoDescription = description.isEmpty ? nil : description
        todo.priority = priority
        todo.dueDate = hasDueDate ? dueDate : nil
        todo.recurrenceRule = recurrenceRule
        repo.update(todo)
        onSave()
        dismiss()
    }

    private var priorityAccentColor: Color {
        switch priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return .blue
        }
    }

    private func priorityColor(_ p: Int) -> Color {
        switch p {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return .gray
        }
    }

    private var todoRecurrenceLabel: String {
        guard let rule = recurrenceRule else { return L10n.doesNotRepeat }
        if rule.daysOfWeek == [1, 2, 3, 4, 5] { return L10n.weekdays }
        switch rule.frequency {
        case .daily: return L10n.daily
        case .weekly: return L10n.weekly
        case .monthly: return L10n.monthly
        case .yearly: return L10n.yearly
        }
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 0: return L10n.priorityNone
        case 1: return L10n.priorityLow
        case 2: return L10n.priorityMedium
        case 3: return L10n.priorityHigh
        default: return ""
        }
    }
}
