import Foundation
import Supabase
import Realtime

@MainActor
public final class RealtimeService {
    public static let shared = RealtimeService()
    private let supabase = SupabaseService.shared.client

    public var onEventParticipantChange: (() -> Void)?
    public var onFriendshipChange: (() -> Void)?
    public var onNotificationChange: (() -> Void)?
    public var onTodoChange: (() -> Void)?

    private var channels: [RealtimeChannelV2] = []

    private init() {}

    public func subscribe(userID: UUID) async {
        let userIDStr = userID.uuidString.lowercased()

        // Event participant changes (filtered to current user)
        let epChannel = supabase.realtimeV2.channel("event_participants")
        let epChanges = epChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "event_participants",
            filter: "user_id=eq.\(userIDStr)"
        )

        // Friendship changes (filtered: user is requester or addressee)
        let friendChannel = supabase.realtimeV2.channel("friendships_req")
        let friendChangesReq = friendChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "friendships",
            filter: "requester_id=eq.\(userIDStr)"
        )

        let friendChannel2 = supabase.realtimeV2.channel("friendships_addr")
        let friendChangesAddr = friendChannel2.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "friendships",
            filter: "addressee_id=eq.\(userIDStr)"
        )

        // Notification changes (filtered to current user)
        let notifChannel = supabase.realtimeV2.channel("notifications")
        let notifChanges = notifChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "notifications",
            filter: "recipient_id=eq.\(userIDStr)"
        )

        // Todo changes (filtered to owner)
        let todoChannel = supabase.realtimeV2.channel("todos")
        let todoChanges = todoChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "todos",
            filter: "owner_id=eq.\(userIDStr)"
        )

        await epChannel.subscribe()
        await friendChannel.subscribe()
        await friendChannel2.subscribe()
        await notifChannel.subscribe()
        await todoChannel.subscribe()

        channels = [epChannel, friendChannel, friendChannel2, notifChannel, todoChannel]

        Task {
            for await _ in epChanges {
                onEventParticipantChange?()
            }
        }

        Task {
            for await _ in friendChangesReq {
                onFriendshipChange?()
            }
        }

        Task {
            for await _ in friendChangesAddr {
                onFriendshipChange?()
            }
        }

        Task {
            for await _ in notifChanges {
                onNotificationChange?()
            }
        }

        Task {
            for await _ in todoChanges {
                onTodoChange?()
            }
        }
    }

    public func unsubscribe() async {
        for channel in channels {
            await supabase.realtimeV2.removeChannel(channel)
        }
        channels = []
    }
}
