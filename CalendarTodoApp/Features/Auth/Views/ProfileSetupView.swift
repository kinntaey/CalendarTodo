import SwiftUI

struct ProfileSetupView: View {
    @Environment(AuthService.self) private var authService
    @State private var username = ""
    @State private var displayName = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private var isValid: Bool {
        username.count >= 3 && username.count <= 20
        && displayName.count >= 1
        && isAvailable == true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("사용자 아이디")
                            .font(.headline)

                        HStack {
                            Text("@")
                                .foregroundStyle(.secondary)
                            TextField("username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: username) { _, newValue in
                                    // Sanitize: only allow lowercase, numbers, underscore
                                    let sanitized = newValue.lowercased().filter {
                                        $0.isLetter || $0.isNumber || $0 == "_"
                                    }
                                    if sanitized != newValue {
                                        username = sanitized
                                    }
                                    isAvailable = nil
                                }
                        }

                        if let isAvailable {
                            HStack(spacing: 4) {
                                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(isAvailable ? "사용 가능" : "이미 사용 중")
                            }
                            .font(.caption)
                            .foregroundStyle(isAvailable ? .green : .red)
                        }
                    }
                } footer: {
                    Text("3~20자, 영문 소문자, 숫자, 밑줄만 가능")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("표시 이름")
                            .font(.headline)
                        TextField("홍길동", text: $displayName)
                    }
                }

                Section {
                    Button {
                        Task { await checkUsername() }
                    } label: {
                        HStack {
                            Text("아이디 확인")
                            if isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(username.count < 3 || isChecking)
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("시작하기")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("프로필 설정")
        }
    }

    private func checkUsername() async {
        isChecking = true
        defer { isChecking = false }
        do {
            isAvailable = try await authService.checkUsernameAvailable(username)
        } catch {
            errorMessage = "확인 실패: \(error.localizedDescription)"
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await authService.createProfile(username: username, displayName: displayName)
        } catch {
            errorMessage = "프로필 생성 실패: \(error.localizedDescription)"
        }
    }
}
