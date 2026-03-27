import CalendarTodoCore
import Foundation
import SwiftUI

// 통합 요청 타입
enum PendingItem: Identifiable {
    case friendRequest(FriendshipWithProfile)
    case eventInvitation(EventInvitation)
    case todoAssignment(PendingAssignment)

    var id: UUID {
        switch self {
        case .friendRequest(let f): return f.friendshipID
        case .eventInvitation(let e): return e.participantID
        case .todoAssignment(let t): return t.todoID
        }
    }
}

@MainActor
@Observable
final class SocialViewModel {
    var friends: [FriendshipWithProfile] = []
    var pendingRequests: [FriendshipWithProfile] = []
    var pendingEventInvitations: [EventInvitation] = []
    var pendingTodoAssignments: [PendingAssignment] = []
    var searchResults: [ProfileResponse] = []
    var sentRequestUserIDs: Set<UUID> = []
    var searchQuery = ""
    var isSearching = false
    var isLoading = false
    var errorMessage: String?

    private let friendshipService = FriendshipService()
    private let eventParticipantService = EventParticipantService()
    private let todoSharingService = TodoSharingService()
    private var currentUserID: UUID?

    // 모든 pending 항목 통합
    var allPendingItems: [PendingItem] {
        var items: [PendingItem] = []
        items += pendingRequests.map { .friendRequest($0) }
        items += pendingEventInvitations.map { .eventInvitation($0) }
        items += pendingTodoAssignments.map { .todoAssignment($0) }
        return items
    }

    var totalPendingCount: Int {
        allPendingItems.count
    }

    func setup(userID: UUID) {
        currentUserID = userID
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let f = friendshipService.fetchFriends()
            async let p = friendshipService.fetchPendingRequests()
            async let s = friendshipService.fetchSentRequests()
            friends = try await f
            pendingRequests = try await p
            sentRequestUserIDs = Set(try await s.map(\.profile.id))
        } catch {
            errorMessage = error.localizedDescription
        }

        // 이벤트 초대 & 할일 배정 (실패해도 무시)
        do {
            pendingEventInvitations = try await eventParticipantService.fetchPendingInvitations()
        } catch {}
        do {
            pendingTodoAssignments = try await todoSharingService.fetchPendingAssignments()
        } catch {}
    }

    var friendIDs: Set<UUID> {
        Set(friends.map(\.profile.id))
    }

    func searchUsers() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await friendshipService.searchUsers(query: query)
            searchResults = results.filter { $0.id != currentUserID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendFriendRequest(to userID: UUID) async {
        // UI 먼저 업데이트
        sentRequestUserIDs.insert(userID)
        do {
            try await friendshipService.sendFriendRequest(to: userID)
        } catch {
            // 실패하면 되돌림
            sentRequestUserIDs.remove(userID)
            errorMessage = error.localizedDescription
        }
    }

    func cancelFriendRequest(to userID: UUID) async {
        do {
            try await friendshipService.cancelFriendRequest(to: userID)
            sentRequestUserIDs.remove(userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptFriendRequest(_ friendship: FriendshipWithProfile) async {
        print("[Social] ACCEPT called for: \(friendship.friendshipID)")
        do {
            try await friendshipService.acceptFriendRequest(friendship.friendshipID)
            print("[Social] Accept done, refreshing...")
            await refresh()
        } catch {
            print("[Social] Accept ERROR: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func declineFriendRequest(_ friendship: FriendshipWithProfile) async {
        print("[Social] DECLINE called for: \(friendship.friendshipID)")
        do {
            try await friendshipService.declineFriendRequest(friendship.friendshipID)
            await refresh()
        } catch {
            print("[Social] Decline ERROR: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    private var processingInvitationIDs: Set<UUID> = []

    func acceptEventInvitation(_ invitation: EventInvitation) async {
        guard !processingInvitationIDs.contains(invitation.participantID) else { return }
        processingInvitationIDs.insert(invitation.participantID)
        defer { processingInvitationIDs.remove(invitation.participantID) }
        do {
            print("[Social] Accepting event invitation: \(invitation.participantID)")
            let clonedID = try await eventParticipantService.respondToInvitation(participantID: invitation.participantID, accept: true)
            print("[Social] Event cloned with ID: \(String(describing: clonedID))")
            pendingEventInvitations.removeAll { $0.participantID == invitation.participantID }
        } catch {
            print("[Social] Accept event ERROR: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func declineEventInvitation(_ invitation: EventInvitation) async {
        do {
            _ = try await eventParticipantService.respondToInvitation(participantID: invitation.participantID, accept: false)
            pendingEventInvitations.removeAll { $0.participantID == invitation.participantID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptTodoAssignment(_ assignment: PendingAssignment) async {
        do {
            try await todoSharingService.respondToAssignment(todoID: assignment.todoID, accept: true)
            pendingTodoAssignments.removeAll { $0.todoID == assignment.todoID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineTodoAssignment(_ assignment: PendingAssignment) async {
        do {
            try await todoSharingService.respondToAssignment(todoID: assignment.todoID, accept: false)
            pendingTodoAssignments.removeAll { $0.todoID == assignment.todoID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friendship: FriendshipWithProfile) async {
        do {
            try await friendshipService.removeFriend(friendship.friendshipID)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
