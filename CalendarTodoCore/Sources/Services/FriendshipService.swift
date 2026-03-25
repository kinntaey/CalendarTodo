import Foundation
import Supabase

@MainActor
public final class FriendshipService {
    private let supabase = SupabaseService.shared.client

    public init() {}

    // MARK: - Search Users

    public func searchUsers(query: String) async throws -> [ProfileResponse] {
        try await supabase
            .from("profiles")
            .select()
            .ilike("username", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value
    }

    // MARK: - Friend Requests

    public func sendFriendRequest(to addresseeID: UUID) async throws {
        let currentUserID = try await supabase.auth.session.user.id
        let requesterStr = currentUserID.uuidString.lowercased()
        let addresseeStr = addresseeID.uuidString.lowercased()
        print("[Friendship] Sending request from \(requesterStr) to \(addresseeStr)")

        struct FriendshipInsert: Encodable {
            let requester_id: String
            let addressee_id: String
        }

        do {
            try await supabase
                .from("friendships")
                .insert(FriendshipInsert(requester_id: requesterStr, addressee_id: addresseeStr))
                .execute()
            print("[Friendship] Insert success")
        } catch {
            print("[Friendship] Insert ERROR: \(error)")
            throw error
        }

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

        // 푸시 알림 전송
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

        let idStr = friendshipID.uuidString.lowercased()
        print("[Friendship] Accepting request: \(idStr)")
        let response = try await supabase
            .from("friendships")
            .update(StatusUpdate(status: "accepted"))
            .eq("id", value: idStr)
            .select()
            .execute()

        print("[Friendship] Accept response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
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

    // MARK: - Fetch Friends

    public func fetchFriends() async throws -> [FriendshipWithProfile] {
        let currentUserID = try await supabase.auth.session.user.id
        let userIDStr = currentUserID.uuidString.lowercased()
        print("[Friendship] Fetching friends for user: \(userIDStr)")

        struct SimpleFriendship: Decodable {
            let id: UUID
            let requester_id: UUID
            let addressee_id: UUID
            let status: String
        }

        // Fetch all accepted friendships
        let all: [SimpleFriendship] = try await supabase
            .from("friendships")
            .select("id, requester_id, addressee_id, status")
            .eq("status", value: "accepted")
            .or("requester_id.eq.\(userIDStr),addressee_id.eq.\(userIDStr)")
            .execute()
            .value

        print("[Friendship] Accepted friendships found: \(all.count)")

        // Get the friend's profile for each
        var results: [FriendshipWithProfile] = []
        for row in all {
            let friendID = row.requester_id == currentUserID ? row.addressee_id : row.requester_id
            let profile: ProfileResponse = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: friendID.uuidString.lowercased())
                .single()
                .execute()
                .value
            results.append(FriendshipWithProfile(friendshipID: row.id, profile: profile))
        }

        print("[Friendship] Total friends: \(results.count)")
        return results
    }

    // MARK: - Fetch Sent Requests (outgoing pending)

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

        var results: [FriendshipWithProfile] = []
        for row in rows {
            let profile: ProfileResponse = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: row.addressee_id.uuidString.lowercased())
                .single()
                .execute()
                .value
            results.append(FriendshipWithProfile(friendshipID: row.id, profile: profile))
        }
        return results
    }

    // MARK: - Fetch Pending Requests (incoming)

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

        var results: [FriendshipWithProfile] = []
        for row in rows {
            let profile: ProfileResponse = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: row.requester_id.uuidString.lowercased())
                .single()
                .execute()
                .value
            results.append(FriendshipWithProfile(friendshipID: row.id, profile: profile))
        }
        return results
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
