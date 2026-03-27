import CalendarTodoCore
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(AuthService.self) private var authService
    @State private var profile: ProfileResponse?
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var appleCalendarEnabled = EventKitService.shared.hasAccess
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Title
                    Text(L10n.settingsTitle)
                        .font(AppTheme.titleFont)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // Account Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.account)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let profile {
                            HStack(spacing: 14) {
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    ZStack(alignment: .bottomTrailing) {
                                        ProfileAvatar(name: profile.displayName, size: 56, avatarURL: profile.avatarURL)

                                        if isUploadingAvatar {
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 56, height: 56)
                                            ProgressView()
                                                .controlSize(.small)
                                        }

                                        Image(systemName: "camera.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white, AppTheme.accent)
                                            .offset(x: 4, y: 4)
                                    }
                                }
                                .onChange(of: selectedPhoto) { _, newValue in
                                    guard let newValue else { return }
                                    Task { await uploadAvatar(item: newValue) }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("@\(profile.username)")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                                    if let email = authService.currentUser?.email {
                                        Text(email)
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if profile.avatarURL != nil {
                                    Button {
                                        Task { await removeAvatar() }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: AppTheme.cardRadius).fill(Color(.systemBackground)))
                    .cardShadow()
                    .padding(.horizontal, 16)

                    // Appearance Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.appearance)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            Text(L10n.timeFormatSetting)
                                .font(.system(size: 15, design: .rounded))

                            Spacer()

                            Picker("", selection: $settings.timeFormat) {
                                ForEach(AppSettings.TimeFormat.allCases, id: \.self) { format in
                                    Text(format.label).tag(format)
                                }
                            }
                            .pickerStyle(.menu)
                            .fixedSize()
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: AppTheme.cardRadius).fill(Color(.systemBackground)))
                    .cardShadow()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Calendar Sync Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.calendarSync)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                let granted = await EventKitService.shared.requestAccess()
                                appleCalendarEnabled = granted
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)

                                Text(L10n.syncAppleCalendar)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if appleCalendarEnabled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: AppTheme.cardRadius).fill(Color(.systemBackground)))
                    .cardShadow()
                    .padding(.horizontal, 16)

                    // Actions
                    VStack(spacing: 0) {
                        Button {
                            showLogoutConfirm = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16))
                                    .frame(width: 28)
                                Text(L10n.logout)
                                    .font(.system(size: 15, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(.primary)
                            .padding(16)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 56)

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .frame(width: 28)
                                Text(L10n.deleteAccount)
                                    .font(.system(size: 15, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(.red)
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(RoundedRectangle(cornerRadius: AppTheme.cardRadius).fill(Color(.systemBackground)))
                    .cardShadow()
                    .padding(.horizontal, 16)

                    // Warning
                    Text(L10n.deleteAccountWarning)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 90)
                }
            }
            .background(Color(.systemBackground))
            .padding(.bottom, 70)
            .navigationBarHidden(true)
            .task {
                do {
                    profile = try await authService.fetchProfile()
                } catch {}
            }
            .alert(L10n.logoutConfirm, isPresented: $showLogoutConfirm) {
                Button(L10n.logout, role: .destructive) {
                    Task {
                        clearLocalData()
                        try? await authService.signOut()
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            }
            .alert(L10n.deleteAccountConfirm, isPresented: $showDeleteConfirm) {
                Button(L10n.deleteAccount, role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button(L10n.cancel, role: .cancel) {}
            }
        }
    }

    private func clearLocalData() {
        do {
            try modelContext.delete(model: LocalEvent.self)
            try modelContext.delete(model: LocalTodo.self)
            try modelContext.delete(model: LocalTodoList.self)
            try modelContext.delete(model: LocalTag.self)
            try modelContext.save()
        } catch {
            print("[Settings] Clear data error: \(error)")
        }
    }

    private func uploadAvatar(item: PhotosPickerItem) async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let url = try await AvatarService.shared.uploadAvatar(imageData: data)
            // Refresh profile to get new URL
            profile = try await authService.fetchProfile()
            selectedPhoto = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeAvatar() async {
        do {
            try await AvatarService.shared.deleteAvatar()
            profile = try await authService.fetchProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            // Call Edge Function to delete auth user (cascades to all data)
            struct EmptyBody: Encodable {}
            try await SupabaseService.shared.client.functions.invoke(
                "delete-account",
                options: .init(body: EmptyBody())
            )
            clearLocalData()
            try await authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
