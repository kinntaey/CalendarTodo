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

        // 이벤트 참가 변경 감지
        let epChannel = supabase.realtimeV2.channel("event_participants")
        let epChanges = epChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "event_participants",
            filter: "user_id=eq.\(userIDStr)"
        )

        // 친구 요청 변경 감지
        let friendChannel = supabase.realtimeV2.channel("friendships")
        let friendChanges = friendChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "friendships"
        )

        // 알림 변경 감지
        let notifChannel = supabase.realtimeV2.channel("notifications")
        let notifChanges = notifChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "notifications",
            filter: "recipient_id=eq.\(userIDStr)"
        )

        // 투두 변경 감지
        let todoChannel = supabase.realtimeV2.channel("todos")
        let todoChanges = todoChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "todos"
        )

        await epChannel.subscribe()
        await friendChannel.subscribe()
        await notifChannel.subscribe()
        await todoChannel.subscribe()

        channels = [epChannel, friendChannel, notifChannel, todoChannel]

        // 변경 감지 리스너
        Task {
            for await _ in epChanges {
                onEventParticipantChange?()
            }
        }

        Task {
            for await _ in friendChanges {
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

        print("[Realtime] Subscribed to channels for user: \(userIDStr)")
    }

    public func unsubscribe() async {
        for channel in channels {
            await supabase.realtimeV2.removeChannel(channel)
        }
        channels = []
        print("[Realtime] Unsubscribed from all channels")
    }
}
