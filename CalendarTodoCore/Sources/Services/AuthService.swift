import AuthenticationServices
import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    private let supabase = SupabaseService.shared.client

    var currentUser: User?
    var isAuthenticated = false
    var isLoading = false

    init() {
        Task {
            await checkSession()
        }
    }

    // MARK: - Session

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        currentUser = session.user
        isAuthenticated = true
    }

    // MARK: - Google Sign In

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        currentUser = session.user
        isAuthenticated = true
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Profile

    func createProfile(username: String, displayName: String) async throws {
        guard let userID = currentUser?.id else { return }

        struct ProfileInsert: Encodable {
            let id: UUID
            let username: String
            let display_name: String
        }

        try await supabase
            .from("profiles")
            .insert(ProfileInsert(
                id: userID,
                username: username,
                display_name: displayName
            ))
            .execute()
    }

    func fetchProfile() async throws -> ProfileResponse? {
        guard let userID = currentUser?.id else { return nil }

        return try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }

    func checkUsernameAvailable(_ username: String) async throws -> Bool {
        let results: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .eq("username", value: username)
            .execute()
            .value

        return results.isEmpty
    }
}

struct ProfileResponse: Decodable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarURL: String?
    let timezone: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, username, timezone
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }
}
