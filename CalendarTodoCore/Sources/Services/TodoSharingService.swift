import Foundation
import Supabase

@MainActor
public final class TodoSharingService {
    private let supabase = SupabaseService.shared.client

    public init() {}

    // MARK: - Assign Todo to Friend

    public func assignTodoToFriend(todoTitle: String, friendID: UUID, assignedDate: Date?) async throws {
        let currentUserID = try await supabase.auth.session.user.id

        struct TodoInsert: Encodable {
            let owner_id: UUID
            let title: String
            let assigned_to: UUID
            let assignment_status: String
            let assigned_date: String?
        }

        let dateStr: String? = assignedDate.map { ISO8601DateFormatter().string(from: $0) }

        // Create todo on server assigned to friend
        try await supabase
            .from("todos")
            .insert(TodoInsert(
                owner_id: currentUserID,
                title: todoTitle,
                assigned_to: friendID,
                assignment_status: "pending",
                assigned_date: dateStr
            ))
            .execute()

        // Send notification
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
        }

        try await supabase
            .from("notifications")
            .insert(NotificationInsert(
                recipient_id: friendID,
                sender_id: currentUserID,
                type: "todo_assigned",
                title: senderProfile.displayName,
                body: todoTitle,
                reference_type: "todo"
            ))
            .execute()

        // Trigger push notification
        struct PushPayload: Encodable {
            let recipient_id: String
            let title: String
            let body: String
        }

        try? await supabase.functions.invoke(
            "send-push-notification",
            options: .init(body: PushPayload(
                recipient_id: friendID.uuidString,
                title: senderProfile.displayName,
                body: todoTitle
            ))
        )
    }

    // MARK: - Respond to Assignment

    public func respondToAssignment(todoID: UUID, accept: Bool) async throws {
        let currentUserID = try await supabase.auth.session.user.id

        if accept {
            // Clone todo for assignee
            try await supabase
                .rpc("clone_todo_for_assignee", params: [
                    "p_todo_id": todoID.uuidString,
                    "p_user_id": currentUserID.uuidString
                ])
                .execute()

            struct StatusUpdate: Encodable {
                let assignment_status: String
            }

            try await supabase
                .from("todos")
                .update(StatusUpdate(assignment_status: "accepted"))
                .eq("id", value: todoID)
                .execute()
        } else {
            struct StatusUpdate: Encodable {
                let assignment_status: String
            }

            try await supabase
                .from("todos")
                .update(StatusUpdate(assignment_status: "declined"))
                .eq("id", value: todoID)
                .execute()
        }
    }

    // MARK: - Fetch Friend's Public Todo Lists

    public func fetchFriendPublicLists(friendID: UUID) async throws -> [RemoteTodoList] {
        try await supabase
            .from("todo_lists")
            .select("*, todos(*)")
            .eq("owner_id", value: friendID)
            .eq("is_deleted", value: false)
            .eq("list_type", value: "custom")
            .eq("is_shared", value: true)
            .execute()
            .value
    }

    // MARK: - Fetch All Friends' Public Lists

    public func fetchAllFriendsPublicLists(friendIDs: [UUID]) async throws -> [FriendTodoLists] {
        guard !friendIDs.isEmpty else { return [] }

        let friendIDStrings = friendIDs.map { $0.uuidString.lowercased() }

        // Batch fetch profiles
        let profiles: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .in("id", values: friendIDStrings)
            .execute()
            .value
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        // Batch fetch all shared lists
        let lists: [RemoteTodoListWithOwner] = try await supabase
            .from("todo_lists")
            .select("id, title, is_shared, created_at, owner_id")
            .in("owner_id", values: friendIDStrings)
            .eq("is_deleted", value: false)
            .eq("list_type", value: "custom")
            .eq("is_shared", value: true)
            .execute()
            .value

        // Group by owner
        let grouped = Dictionary(grouping: lists) { $0.owner_id }

        return grouped.compactMap { ownerID, ownerLists in
            guard let profile = profileMap[ownerID] else { return nil }
            let remoteLists = ownerLists.map { RemoteTodoList(id: $0.id, title: $0.title, is_shared: $0.is_shared, created_at: $0.created_at) }
            return FriendTodoLists(profile: profile, lists: remoteLists)
        }
    }

    // MARK: - Fetch Todos in a List

    public func fetchTodosInList(listID: UUID) async throws -> [RemoteTodo] {
        try await supabase
            .from("todos")
            .select()
            .eq("todo_list_id", value: listID)
            .eq("is_deleted", value: false)
            .order("sort_order")
            .execute()
            .value
    }

    // MARK: - Fetch Pending Assignments for Me

    public func fetchPendingAssignments() async throws -> [PendingAssignment] {
        let currentUserID = try await supabase.auth.session.user.id

        let rows: [AssignmentRow] = try await supabase
            .from("todos")
            .select("*, assigner:profiles!owner_id(*)")
            .eq("assigned_to", value: currentUserID)
            .eq("assignment_status", value: "pending")
            .eq("is_deleted", value: false)
            .execute()
            .value

        return rows.compactMap { row in
            guard let assigner = row.assigner else { return nil }
            return PendingAssignment(todoID: row.id, title: row.title, assigner: assigner)
        }
    }
}

// MARK: - Response Types

public struct RemoteTodoList: Decodable, Identifiable {
    public let id: UUID
    public let title: String
    public let is_shared: Bool
    public let created_at: Date
}

public struct RemoteTodo: Decodable, Identifiable {
    public let id: UUID
    public let title: String
    public let is_completed: Bool
    public let sort_order: Int
    public let assigned_date: String?
}

public struct FriendTodoLists: Identifiable {
    public let profile: ProfileResponse
    public let lists: [RemoteTodoList]
    public var id: UUID { profile.id }
}

public struct AssignmentRow: Decodable {
    public let id: UUID
    public let title: String
    public let assigner: ProfileResponse?
}

public struct PendingAssignment: Identifiable {
    public let todoID: UUID
    public let title: String
    public let assigner: ProfileResponse
    public var id: UUID { todoID }
}

struct RemoteTodoListWithOwner: Decodable {
    let id: UUID
    let title: String
    let is_shared: Bool
    let created_at: Date
    let owner_id: UUID
}
