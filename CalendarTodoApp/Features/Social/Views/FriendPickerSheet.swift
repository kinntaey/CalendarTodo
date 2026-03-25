import CalendarTodoCore
import SwiftUI

struct FriendPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFriendIDs: [UUID]
    let friends: [FriendshipWithProfile]

    var body: some View {
        NavigationStack {
            List {
                ForEach(friends) { friend in
                    let isSelected = selectedFriendIDs.contains(friend.profile.id)

                    Button {
                        if isSelected {
                            selectedFriendIDs.removeAll { $0 == friend.profile.id }
                        } else {
                            selectedFriendIDs.append(friend.profile.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ProfileAvatar(name: friend.profile.displayName, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.profile.displayName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("@\(friend.profile.username)")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                                    .font(.system(size: 22))
                            } else {
                                Circle()
                                    .stroke(Color(.systemGray3), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(L10n.inviteFriends)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                        .bold()
                }
            }
        }
    }
}

// MARK: - Single Select Friend Picker

struct FriendSinglePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFriendID: UUID?
    let friends: [FriendshipWithProfile]

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedFriendID = nil
                    dismiss()
                } label: {
                    HStack {
                        Text(L10n.priorityNone)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedFriendID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }

                ForEach(friends) { friend in
                    Button {
                        selectedFriendID = friend.profile.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ProfileAvatar(name: friend.profile.displayName, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.profile.displayName)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("@\(friend.profile.username)")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedFriendID == friend.profile.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(L10n.assignToFriend)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
    }
}
