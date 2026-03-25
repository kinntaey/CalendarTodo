import Foundation
import Supabase

#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PushNotificationService {
    public static let shared = PushNotificationService()
    private let supabase = SupabaseService.shared.client

    private init() {}

    // MARK: - Request Permission

    #if canImport(UIKit)
    public func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("[Push] Permission error: \(error)")
            return false
        }
    }
    #endif

    // MARK: - Register Device Token

    public func registerDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Device token: \(token)")

        do {
            let userID = try await supabase.auth.session.user.id

            // 현재 토큰만 저장 (이전 토큰 제거)
            struct TokenUpdate: Encodable {
                let apns_device_tokens: [String]
            }

            try await supabase
                .from("profiles")
                .update(TokenUpdate(apns_device_tokens: [token]))
                .eq("id", value: userID)
                .execute()

            print("[Push] Token registered successfully")
        } catch {
            print("[Push] Token registration error: \(error)")
        }
    }

    // MARK: - Remove Device Token

    public func removeDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()

        do {
            let userID = try await supabase.auth.session.user.id

            struct TokenRow: Decodable {
                let apns_device_tokens: [String]?
            }

            let row: TokenRow = try await supabase
                .from("profiles")
                .select("apns_device_tokens")
                .eq("id", value: userID)
                .single()
                .execute()
                .value

            var tokens = row.apns_device_tokens ?? []
            tokens.removeAll { $0 == token }

            struct TokenUpdate: Encodable {
                let apns_device_tokens: [String]
            }

            try await supabase
                .from("profiles")
                .update(TokenUpdate(apns_device_tokens: tokens))
                .eq("id", value: userID)
                .execute()
        } catch {
            print("[Push] Token removal error: \(error)")
        }
    }
}
