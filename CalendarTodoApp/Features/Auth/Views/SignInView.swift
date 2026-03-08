import AuthenticationServices
import CalendarTodoCore
import CryptoKit
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var authService
    @State private var currentNonce: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // App Logo & Title
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("CalendarTodo")
                    .font(.largeTitle.bold())

                Text("캘린더와 할 일을 한 곳에서")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sign In Buttons
            VStack(spacing: 16) {
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
                .frame(height: 50)

                // Google Sign In
                Button {
                    // TODO: Implement Google Sign In with GoogleSignIn SDK
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Google로 로그인")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
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
                errorMessage = "Apple 인증 정보를 가져올 수 없습니다."
                return
            }

            Task {
                do {
                    try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                } catch {
                    errorMessage = "로그인에 실패했습니다: \(error.localizedDescription)"
                }
            }

        case .failure(let error):
            errorMessage = "Apple 로그인 실패: \(error.localizedDescription)"
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
