import CalendarTodoCore
import SwiftUI

struct ProfileSetupView: View {
    @Environment(AuthService.self) private var authService
    var onComplete: () -> Void = {}
    @State private var username = ""
    @State private var displayName = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool?
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var checkTask: Task<Void, Never>?

    private var canSubmit: Bool {
        username.count >= 3 && username.count <= 20
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.accent)

                Text(L10n.profileSetup)
                    .font(AppTheme.displayFont)

                Text(L10n.welcomeSubtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)

            // Username
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.userId)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("@")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("username", text: $username)
                        .font(.system(size: 17, design: .rounded))
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .onChange(of: username) { _, newValue in
                            let sanitized = newValue.lowercased().filter {
                                $0.isLetter || $0.isNumber || $0 == "_"
                            }
                            if sanitized != newValue {
                                username = sanitized
                            }
                            isAvailable = nil
                            checkTask?.cancel()
                            guard sanitized.count >= 3 else { return }
                            checkTask = Task {
                                try? await Task.sleep(for: .milliseconds(500))
                                guard !Task.isCancelled else { return }
                                await checkUsername()
                            }
                        }

                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else if let isAvailable {
                        Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isAvailable ? .green : .red)
                    }
                }
                .padding(14)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isAvailable == false ? Color.red : .clear, lineWidth: 1.5)
                )

                if isAvailable == false {
                    Text(L10n.alreadyInUse)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .padding(.leading, 4)
                } else {
                    Text(L10n.usernameRules)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }

            Spacer()

            // Submit button
            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                    }
                    Text(L10n.getStarted)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    canSubmit ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(Color.gray.opacity(0.3)),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(!canSubmit || isSubmitting)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func checkUsername() async {
        isChecking = true
        defer { isChecking = false }
        do {
            isAvailable = try await authService.checkUsernameAvailable(username)
        } catch {
            errorMessage = L10n.checkFailed(error.localizedDescription)
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let available = try await authService.checkUsernameAvailable(username)
            isAvailable = available
            guard available else { return }
            try await authService.createProfile(username: username, displayName: username)
            onComplete()
        } catch {
            errorMessage = L10n.profileCreateFailed(error.localizedDescription)
        }
    }
}
