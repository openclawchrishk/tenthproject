import Foundation
import Supabase

/// Central Supabase client. Replace URL and anon key with your project values (or load from Info.plist / xcconfig).
final class SupabaseManager {
    static let shared = SupabaseManager()

    private let supabaseUrl = URL(string: "https://your-project.supabase.co")!
    private let supabaseAnonKey = "your-anon-key"

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseAnonKey)
    }
}

extension SupabaseManager {
    var auth: AuthClient {
        client.auth
    }
}
