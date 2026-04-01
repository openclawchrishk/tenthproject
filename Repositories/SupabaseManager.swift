import Foundation
import Supabase

/*
 Configure production credentials using either:

 1) Xcode scheme environment (Run → Arguments → Environment):
    - SUPABASE_URL   (e.g. https://abcd1234.supabase.co)
    - SUPABASE_ANON_KEY or SUPABASE_KEY  (project anon/public key)

 2) `Info.plist` keys `SUPABASE_URL` and `SUPABASE_ANON_KEY` (values via xcconfig or build settings; do not commit secrets).

 No embedded API keys are shipped in source — set real values in CI / local scheme.
 */
final class SupabaseManager {
    static let shared = SupabaseManager()

    private let supabaseUrl: URL
    private let supabaseAnonKey: String

    let client: SupabaseClient

    private init() {
        let url = Self.resolvedURL()
        let key = Self.resolvedAnonKey()
        supabaseUrl = url
        supabaseAnonKey = key

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        let urlSession = URLSession(configuration: config)

        let options = SupabaseClientOptions(
            global: SupabaseClientOptions.GlobalOptions(session: urlSession)
        )
        client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseAnonKey, options: options)
    }

    /// Prefer env, then Info.plist; last resort is non-routable placeholder (no network secrets in binary).
    private static func resolvedURL() -> URL {
        if let u = urlFromEnvironment() { return u }
        if let raw = stringFromInfoPlist("SUPABASE_URL") {
            let normalized = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
            if let u = URL(string: normalized) { return u }
        }
        return URL(string: "https://127.0.0.1") ?? URL(fileURLWithPath: "/")
    }

    private static func resolvedAnonKey() -> String {
        if let k = anonKeyFromEnvironment(), !k.isEmpty { return k }
        if let k = stringFromInfoPlist("SUPABASE_ANON_KEY"), !k.isEmpty { return k }
        if let k = stringFromInfoPlist("SUPABASE_KEY"), !k.isEmpty { return k }
        return ""
    }

    private static func stringFromInfoPlist(_ key: String) -> String? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
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
