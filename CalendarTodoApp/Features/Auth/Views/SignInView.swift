import AuthenticationServices
import CalendarTodoCore
import CryptoKit
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var authService
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var showEmailForm = false
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Logo & Title
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 56))
                    .foregroundStyle(.primary)

                Text("Plan Todo")
                    .font(AppTheme.displayFont)

                Text(L10n.calendarAndTodo)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sign In Buttons
            VStack(spacing: 12) {
                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Email Sign In
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showEmailForm.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                        Text(L10n.signInWithEmail)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.primary)
                }

                // Email Form
                if showEmailForm {
                    VStack(spacing: 10) {
                        TextField(L10n.email, text: $email)
                            .textContentType(.emailAddress)
                            #if !os(macOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            #endif
                            .autocorrectionDisabled()
                            .font(.system(size: 15, design: .rounded))
                            .padding(14)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                        SecureField(L10n.password, text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .font(.system(size: 15, design: .rounded))
                            .padding(14)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                        Button {
                            isSignUp.toggle()
                        } label: {
                            if isSignUp {
                                HStack(spacing: 0) {
                                    Text(L10n.hasAccount)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text(" \(L10n.signIn)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .underline()
                                }
                            } else {
                                HStack(spacing: 0) {
                                    Text(L10n.noAccount)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Text(" \(L10n.signUp)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .underline()
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await handleEmailAuth() }
                        } label: {
                            Text(isSignUp ? L10n.signUp : L10n.signIn)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    email.isEmpty || password.count < 6
                                    ? AnyShapeStyle(Color.gray.opacity(0.3))
                                    : AnyShapeStyle(AppTheme.accentGradient),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }
                        .disabled(email.isEmpty || password.count < 6)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Email Auth

    private func handleEmailAuth() async {
        errorMessage = nil
        do {
            if isSignUp {
                try await authService.signUpWithEmail(email: email, password: password)
            } else {
                try await authService.signInWithEmail(email: email, password: password)
            }
        } catch {
            errorMessage = L10n.signInFailed(error.localizedDescription)
        }
    }

    // MARK: - Apple Sign In Handler

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                errorMessage = L10n.appleCredentialError
                return
            }

            Task {
                do {
                    try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                } catch {
                    errorMessage = L10n.signInFailed(error.localizedDescription)
                }
            }

        case .failure(let error):
            errorMessage = L10n.appleSignInFailed(error.localizedDescription)
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce: \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
