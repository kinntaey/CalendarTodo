import Foundation
import Supabase

@MainActor
public final class FriendshipService {
    private let supabase = SupabaseService.shared.client

    public init() {}

    // MARK: - Search Users

    public func searchUsers(query: String) async throws -> [ProfileResponse] {
        // Escape ILIKE special characters
        let escaped = query
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")

        let results: [ProfileSearchResult] = try await supabase
            .from("profiles")
            .select("id, username, display_name, avatar_url, timezone, created_at")
            .ilike("username", pattern: "%\(escaped)%")
            .limit(20)
            .execute()
            .value

        return results.map {
            ProfileResponse(id: $0.id, username: $0.username, displayName: $0.display_name ?? $0.username,
                          avatarURL: $0.avatar_url, timezone: $0.timezone, createdAt: $0.created_at)
        }
    }

    // MARK: - Friend Requests

    public func sendFriendRequest(to addresseeID: UUID) async throws {
        let currentUserID = try await supabase.auth.session.user.id
        let requesterStr = currentUserID.uuidString.lowercased()
        let addresseeStr = addresseeID.uuidString.lowercased()

        struct FriendshipInsert: Encodable {
            let requester_id: String
            let addressee_id: String
        }

        try await supabase
            .from("friendships")
            .insert(FriendshipInsert(requester_id: requesterStr, addressee_id: addresseeStr))
            .execute()

        // Create notification
        let senderProfile: ProfileResponse = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: currentUserID)
            .single()
            .execute()
            .value

        struct NotificationInsert: Encodable {
            let recipient_id: UUID
            let sender_id: UUID
            let type: String
            let title: String
            let body: String?
            let reference_type: String
            let reference_id: UUID?
        }

        try await supabase
            .from("notifications")
            .insert(NotificationInsert(
                recipient_id: addresseeID,
                sender_id: currentUserID,
                type: "friend_request",
                title: "@\(senderProfile.username)",
                body: "friend_request",
                reference_type: "friendship",
                reference_id: nil
            ))
            .execute()

        // Push notification
        struct PushPayload: Encodable {
            let recipient_id: String
            let title: String
            let body: String
        }

        try? await supabase.functions.invoke(
            "send-push-notification",
            options: .init(body: PushPayload(
                recipient_id: addresseeID.uuidString,
                title: "CalendarTodo",
                body: "@\(senderProfile.username) sent you a friend request"
            ))
        )
    }

    public func acceptFriendRequest(_ friendshipID: UUID) async throws {
        struct StatusUpdate: Encodable {
            let status: String
        }

        try await supabase
            .from("friendships")
            .update(StatusUpdate(status: "accepted"))
            .eq("id", value: friendshipID.uuidString.lowercased())
            .select()
            .execute()
    }

    public func declineFriendRequest(_ friendshipID: UUID) async throws {
        try await supabase
            .from("friendships")
            .delete()
            .eq("id", value: friendshipID.uuidString.lowercased())
            .execute()
    }

    public func removeFriend(_ friendshipID: UUID) async throws {
        try await supabase
            .from("friendships")
            .delete()
            .eq("id", value: friendshipID.uuidString.lowercased())
            .execute()
    }

    public func cancelFriendRequest(to addresseeID: UUID) async throws {
        let currentUserID = try await supabase.auth.session.user.id
        let userIDStr = currentUserID.uuidString.lowercased()

        try await supabase
            .from("friendships")
            .delete()
            .eq("requester_id", value: userIDStr)
            .eq("addressee_id", value: addresseeID.uuidString.lowercased())
            .eq("status", value: "pending")
            .execute()
    }

    // MARK: - Fetch Friends (batch profile fetch)

    public func fetchFriends() async throws -> [FriendshipWithProfile] {
        let currentUserID = try await supabase.auth.session.user.id
        let userIDStr = currentUserID.uuidString.lowercased()

        struct SimpleFriendship: Decodable {
            let id: UUID
            let requester_id: UUID
            let addressee_id: UUID
            let status: String
        }

        let all: [SimpleFriendship] = try await supabase
            .from("friendships")
            .select("id, requester_id, addressee_id, status")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userIDStr),addressee_id.eq.\(userIDStr)")
            .execute()
            .value

        guard !all.isEmpty else { return [] }

        // Batch fetch all friend profiles
        let friendIDs = all.map { $0.requester_id == currentUserID ? $0.addressee_id : $0.requester_id }
        let friendIDStrings = friendIDs.map { $0.uuidString.lowercased() }

        let profiles: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .in("id", values: friendIDStrings)
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return all.compactMap { row in
            let friendID = row.requester_id == currentUserID ? row.addressee_id : row.requester_id
            guard let profile = profileMap[friendID] else { return nil }
            return FriendshipWithProfile(friendshipID: row.id, profile: profile)
        }
    }

    // MARK: - Fetch Sent Requests (batch)

    public func fetchSentRequests() async throws -> [FriendshipWithProfile] {
        let currentUserID = try await supabase.auth.session.user.id
        let userIDStr = currentUserID.uuidString.lowercased()

        struct SimpleFriendship: Decodable {
            let id: UUID
            let addressee_id: UUID
        }

        let rows: [SimpleFriendship] = try await supabase
            .from("friendships")
            .select("id, addressee_id")
            .eq("requester_id", value: userIDStr)
            .eq("status", value: "pending")
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        let ids = rows.map { $0.addressee_id.uuidString.lowercased() }
        let profiles: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return rows.compactMap { row in
            guard let profile = profileMap[row.addressee_id] else { return nil }
            return FriendshipWithProfile(friendshipID: row.id, profile: profile)
        }
    }

    // MARK: - Fetch Pending Requests (batch)

    public func fetchPendingRequests() async throws -> [FriendshipWithProfile] {
        let currentUserID = try await supabase.auth.session.user.id
        let userIDStr = currentUserID.uuidString.lowercased()

        struct SimpleFriendship: Decodable {
            let id: UUID
            let requester_id: UUID
        }

        let rows: [SimpleFriendship] = try await supabase
            .from("friendships")
            .select("id, requester_id")
            .eq("addressee_id", value: userIDStr)
            .eq("status", value: "pending")
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        let ids = rows.map { $0.requester_id.uuidString.lowercased() }
        let profiles: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return rows.compactMap { row in
            guard let profile = profileMap[row.requester_id] else { return nil }
            return FriendshipWithProfile(friendshipID: row.id, profile: profile)
        }
    }

    // MARK: - Check existing friendship

    public func existingFriendshipStatus(with userID: UUID) async throws -> String? {
        let currentUserID = try await supabase.auth.session.user.id

        let rows: [FriendshipStatusRow] = try await supabase
            .from("friendships")
            .select("id, status")
            .or("and(requester_id.eq.\(currentUserID),addressee_id.eq.\(userID)),and(requester_id.eq.\(userID),addressee_id.eq.\(currentUserID))")
            .execute()
            .value

        return rows.first?.status
    }
}

// MARK: - Response Types

public struct FriendshipRow: Decodable {
    public let id: UUID
    public let requester_id: UUID
    public let addressee_id: UUID
    public let status: String
    public let requester: ProfileResponse?
    public let addressee: ProfileResponse?
}

public struct FriendshipWithProfile: Identifiable {
    public let friendshipID: UUID
    public let profile: ProfileResponse
    public var id: UUID { friendshipID }
}

struct FriendshipStatusRow: Decodable {
    let id: UUID
    let status: String
}

private struct ProfileSearchResult: Decodable {
    let id: UUID
    let username: String
    let display_name: String?
    let avatar_url: String?
    let timezone: String
    let created_at: Date

    enum CodingKeys: String, CodingKey {
        case id, username, display_name, avatar_url, timezone, created_at
    }
}
