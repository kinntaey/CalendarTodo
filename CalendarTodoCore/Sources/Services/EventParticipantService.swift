import Foundation
import Supabase

@MainActor
public final class EventParticipantService {
    private let supabase = SupabaseService.shared.client

    public init() {}

    // MARK: - Invite Friends

    public func inviteFriends(eventID: UUID, friendIDs: [UUID]) async throws {
        let currentUserID = try await supabase.auth.session.user.id

        struct ParticipantInsert: Encodable {
            let event_id: UUID
            let user_id: UUID
            let status: String
            let invited_by: UUID
        }

        let inserts = friendIDs.map {
            ParticipantInsert(event_id: eventID, user_id: $0, status: "pending", invited_by: currentUserID)
        }

        try await supabase
            .from("event_participants")
            .insert(inserts)
            .execute()

        // Create notifications
        let senderProfile: ProfileResponse = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: currentUserID)
            .single()
            .execute()
            .value

        // Fetch event title
        struct EventTitle: Decodable { let title: String }
        let event: EventTitle = try await supabase
            .from("events")
            .select("title")
            .eq("id", value: eventID)
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
            let reference_id: UUID
        }

        struct PushPayload: Encodable {
            let recipient_id: String
            let title: String
            let body: String
        }

        for friendID in friendIDs {
            try await supabase
                .from("notifications")
                .insert(NotificationInsert(
                    recipient_id: friendID,
                    sender_id: currentUserID,
                    type: "event_invitation",
                    title: "@\(senderProfile.username)",
                    body: event.title,
                    reference_type: "event_participant",
                    reference_id: eventID
                ))
                .execute()

            // 푸시 알림 전송
            try? await supabase.functions.invoke(
                "send-push-notification",
                options: .init(body: PushPayload(
                    recipient_id: friendID.uuidString.lowercased(),
                    title: "CalendarTodo",
                    body: "@\(senderProfile.username) invited you to '\(event.title)'"
                ))
            )
        }
    }

    // MARK: - Respond to Invitation

    public func respondToInvitation(participantID: UUID, accept: Bool) async throws -> UUID? {
        if accept {
            // Get participant info to find event
            struct ParticipantInfo: Decodable {
                let id: UUID
                let event_id: UUID
                let user_id: UUID
            }

            let participant: ParticipantInfo = try await supabase
                .from("event_participants")
                .select("id, event_id, user_id")
                .eq("id", value: participantID.uuidString.lowercased())
                .single()
                .execute()
                .value

            // Update status
            struct StatusUpdate: Encodable {
                let status: String
            }

            try await supabase
                .from("event_participants")
                .update(StatusUpdate(status: "accepted"))
                .eq("id", value: participantID.uuidString.lowercased())
                .execute()

            // Clone event
            let response = try await supabase
                .rpc("clone_event_for_participant", params: [
                    "p_event_id": participant.event_id.uuidString.lowercased(),
                    "p_user_id": participant.user_id.uuidString.lowercased()
                ])
                .execute()

            let responseStr = String(data: response.data, encoding: .utf8) ?? ""

            // Parse UUID from response (could be raw string or JSON)
            if let clonedID = UUID(uuidString: responseStr.trimmingCharacters(in: CharacterSet(charactersIn: "\""))) {
                return clonedID
            }
            return nil
        } else {
            struct StatusUpdate: Encodable {
                let status: String
            }

            try await supabase
                .from("event_participants")
                .update(StatusUpdate(status: "declined"))
                .eq("id", value: participantID.uuidString.lowercased())
                .execute()

            return nil
        }
    }

    // MARK: - Fetch Cloned Event Details

    public func fetchEventDetails(_ eventID: UUID) async throws -> FullEventResponse {
        try await supabase
            .from("events")
            .select()
            .eq("id", value: eventID.uuidString.lowercased())
            .single()
            .execute()
            .value
    }

    // MARK: - Fetch Participants

    public func fetchParticipants(for eventID: UUID) async throws -> [ParticipantWithProfile] {
        let rows: [ParticipantRow] = try await supabase
            .from("event_participants")
            .select("*, user:profiles!user_id(*)")
            .eq("event_id", value: eventID)
            .execute()
            .value

        return rows.compactMap { row in
            guard let profile = row.user else { return nil }
            return ParticipantWithProfile(
                participantID: row.id,
                eventID: row.event_id,
                status: row.status,
                profile: profile
            )
        }
    }

    // MARK: - Fetch Participants by Event ID

    public func fetchParticipantsForEvent(_ eventID: UUID) async throws -> [ParticipantWithProfile] {
        let eventIDStr = eventID.uuidString.lowercased()

        // Get event owner
        struct EventOwner: Decodable { let owner_id: UUID }
        let ownerRow: EventOwner = try await supabase
            .from("events")
            .select("owner_id")
            .eq("id", value: eventIDStr)
            .single()
            .execute()
            .value

        struct SimpleParticipant: Decodable {
            let id: UUID
            let user_id: UUID
            let status: String
        }

        let rows: [SimpleParticipant] = try await supabase
            .from("event_participants")
            .select("id, user_id, status")
            .eq("event_id", value: eventIDStr)
            .execute()
            .value

        // Batch fetch all profiles
        var allIDs = rows.map { $0.user_id.uuidString.lowercased() }
        allIDs.append(ownerRow.owner_id.uuidString.lowercased())

        let profiles: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .in("id", values: allIDs)
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        var results: [ParticipantWithProfile] = []

        // Add event owner first
        if let ownerProfile = profileMap[ownerRow.owner_id] {
            results.append(ParticipantWithProfile(
                participantID: UUID(),
                eventID: eventID,
                status: "owner",
                profile: ownerProfile
            ))
        }

        // Add invited participants
        for row in rows {
            if let profile = profileMap[row.user_id] {
                results.append(ParticipantWithProfile(
                    participantID: row.id,
                    eventID: eventID,
                    status: row.status,
                    profile: profile
                ))
            }
        }
        return results
    }

    // MARK: - Fetch My Pending Invitations

    public func fetchPendingInvitations() async throws -> [EventInvitation] {
        let currentUserID = try await supabase.auth.session.user.id
        let userIDStr = currentUserID.uuidString.lowercased()

        struct SimpleParticipant: Decodable {
            let id: UUID
            let event_id: UUID
            let invited_by: UUID
        }

        let rows: [SimpleParticipant] = try await supabase
            .from("event_participants")
            .select("id, event_id, invited_by")
            .eq("user_id", value: userIDStr)
            .eq("status", value: "pending")
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        // Batch fetch events
        let eventIDs = rows.map { $0.event_id.uuidString.lowercased() }
        let events: [EventResponse] = try await supabase
            .from("events")
            .select("id, title, description, start_at, end_at, is_all_day, location_name, color")
            .in("id", values: eventIDs)
            .execute()
            .value
        let eventMap = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })

        // Batch fetch inviters
        let inviterIDs = Array(Set(rows.map { $0.invited_by.uuidString.lowercased() }))
        let inviters: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .in("id", values: inviterIDs)
            .execute()
            .value
        let inviterMap = Dictionary(uniqueKeysWithValues: inviters.map { ($0.id, $0) })

        return rows.compactMap { row in
            guard let event = eventMap[row.event_id],
                  let inviter = inviterMap[row.invited_by] else { return nil }
            return EventInvitation(participantID: row.id, event: event, inviter: inviter)
        }
    }
}

// MARK: - Response Types

public struct ParticipantRow: Decodable {
    public let id: UUID
    public let event_id: UUID
    public let user_id: UUID
    public let status: String
    public let user: ProfileResponse?
}

public struct ParticipantWithProfile: Identifiable {
    public let participantID: UUID
    public let eventID: UUID
    public let status: String
    public let profile: ProfileResponse
    public var id: UUID { participantID }
}

public struct InvitationRow: Decodable {
    public let id: UUID
    public let event_id: UUID
    public let status: String
    public let event: EventResponse?
    public let inviter: ProfileResponse?
}

public struct FullEventResponse: Decodable {
    public let id: UUID
    public let owner_id: UUID
    public let title: String
    public let description: String?
    public let start_at: Date
    public let end_at: Date
    public let is_all_day: Bool
    public let location_name: String?
    public let location_address: String?
    public let location_lat: Double?
    public let location_lng: Double?
    public let location_place_id: String?
    public let alarms: [Int]?
    public let color: String?
}

public struct EventResponse: Decodable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let start_at: Date
    public let end_at: Date
    public let is_all_day: Bool
    public let location_name: String?
    public let color: String?
}

public struct EventInvitation: Identifiable {
    public let participantID: UUID
    public let event: EventResponse
    public let inviter: ProfileResponse
    public var id: UUID { participantID }
}
