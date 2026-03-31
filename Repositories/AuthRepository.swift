import Foundation
import Supabase

class AuthRepository: ObservableObject {
    @Published var currentUser: User?
    @Published var session: Session?
    
    private let client = SupabaseManager.shared.client
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        // 實現 Apple Sign-In
        // let response = try await client.auth.signInWithIdToken(provider: .apple, idToken: idToken, nonce: nonce)
        // self.session = response.session
        // try await fetchUserProfile()
    }
    
    func signInWithPhone(phone: String) async throws {
        // 實現手機號 OTP 登入
        // try await client.auth.signInWithOTP(phone: phone)
    }
    
    func verifyOTP(phone: String, token: String) async throws {
        // 驗證 OTP
        // let response = try await client.auth.verifyOTP(phone: phone, token: token, type: .sms)
        // self.session = response.session
        // try await fetchUserProfile()
    }
    
    func fetchUserProfile() async throws {
        guard let userId = session?.user.id else { return }
        // 從 users 表獲取用戶資料
        // let user: User = try await client.database.from("users").select().eq("id", value: userId).single().execute().value
        // self.currentUser = user
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
        self.session = nil
    }
}
