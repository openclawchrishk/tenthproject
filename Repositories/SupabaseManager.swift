import Foundation
import Supabase

/*
 FATAL — Supabase is not configured for production until you either:
 1) Set environment variables in the Xcode scheme (Run → Arguments → Environment):
    - SUPABASE_URL   (e.g. https://abcd1234.supabase.co)
    - SUPABASE_ANON_KEY or SUPABASE_KEY  (project anon/public key)
 2) Or replace the fallback URL and key below with real values from the Supabase dashboard.

 Without valid credentials, auth and database calls will fail at runtime.
 */
final class SupabaseManager {
    static let shared = SupabaseManager()

    private let supabaseUrl: URL
    private let supabaseAnonKey: String

    let client: SupabaseClient

    private init() {
        if let url = Self.urlFromEnvironment(), let key = Self.anonKeyFromEnvironment() {
            supabaseUrl = url
            supabaseAnonKey = key
        } else {
            // Chris Lau's Supabase project
            guard let fallback = URL(string: "https://dxihaspyxzocrnxyhbhow.supabase.co") else {
                preconditionFailure("Invalid fallback Supabase URL")
            }
            supabaseUrl = fallback
            supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4aWhhc3B5eHpvY3JueHloYm93Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2ODUwNjQsImV4cCI6MjA5MDI2MTA2NH0.NzJj0qKNjKigPZ-Gp_rxQPG0_3h6QUwcLAXok4yhwsw"
        }
        client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseAnonKey)
    }

    private static func urlFromEnvironment() -> URL? {
        let raw = ProcessInfo.processInfo.environment["SUPABASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        let normalized = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
        return URL(string: normalized)
    }

    private static func anonKeyFromEnvironment() -> String? {
        let env = ProcessInfo.processInfo.environment
        let key = (env["SUPABASE_ANON_KEY"] ?? env["SUPABASE_KEY"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty else { return nil }
        return key
    }
}

extension SupabaseManager {
    var auth: AuthClient {
        client.auth
    }
}
