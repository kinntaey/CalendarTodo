import Foundation
import Supabase

public final class SupabaseService {
    public static let shared = SupabaseService()

    public let client: SupabaseClient

    private init() {
        guard let supabaseURL = URL(string: SupabaseSecrets.url) else {
            fatalError("Invalid Supabase URL: \(SupabaseSecrets.url)")
        }
        let supabaseKey = SupabaseSecrets.anonKey

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
}
