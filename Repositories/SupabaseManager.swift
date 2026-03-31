import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    private let supabaseUrl = URL(string: "https://your-project.supabase.co")!
    private let supabaseAnonKey = "your-anon-key"
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseAnonKey)
    }
}

// 基礎 Auth 輔助工具
extension SupabaseManager {
    var auth: AuthClient {
        client.auth
    }
    
    var database: PostgrestClient {
        client.database
    }
    
    var storage: StorageClient {
        client.storage
    }
}
