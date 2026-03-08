import AuthenticationServices
import Foundation
import Supabase

@MainActor
@Observable
public final class AuthService {
    private let supabase = SupabaseService.shared.client

    public var currentUser: User?
    public var isAuthenticated = false
    public var isLoading = false

    public init() {
        Task {
            await checkSession()
        }
    }

    // MARK: - Session

    public func checkSession() async {
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

    public func signInWithApple(idToken: String, nonce: String) async throws {
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

    public func signInWithGoogle(idToken: String, accessToken: String) async throws {
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

    public func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Profile

    public func createProfile(username: String, displayName: String) async throws {
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

    public func fetchProfile() async throws -> ProfileResponse? {
        guard let userID = currentUser?.id else { return nil }

        return try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }

    public func checkUsernameAvailable(_ username: String) async throws -> Bool {
        let results: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .eq("username", value: username)
            .execute()
            .value

        return results.isEmpty
    }
}

public struct ProfileResponse: Decodable {
    public let id: UUID
    public let username: String
    public let displayName: String
    public let avatarURL: String?
    public let timezone: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, username, timezone
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }

    public init(id: UUID, username: String, displayName: String, avatarURL: String?, timezone: String, createdAt: Date) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.timezone = timezone
        self.createdAt = createdAt
    }
}
