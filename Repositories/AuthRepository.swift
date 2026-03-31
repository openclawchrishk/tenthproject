import Foundation
import Supabase

@MainActor
final class AuthRepository: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var session: Session?

    private let client = SupabaseManager.shared.client
    private var authListenerTask: Task<Void, Never>?

    init() {
        authListenerTask = Task { @MainActor in
            for await (_, session) in await SupabaseManager.shared.client.auth.authStateChanges {
                self.session = session
                if let session {
                    do {
                        try await fetchUserProfile(userId: session.user.id)
                    } catch {
                        self.currentUser = nil
                    }
                } else {
                    self.currentUser = nil
                }
            }
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    func fetchUserProfile(userId: UUID) async throws {
        let profile: UserProfile = try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        self.currentUser = profile
    }

    func refreshProfile() async {
        guard let uid = session?.user.id else { return }
        try? await fetchUserProfile(userId: uid)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signInWithPhone(phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
    }

    func verifyOTP(phone: String, token: String) async throws {
        _ = try await client.auth.verifyOTP(
            phone: phone,
            token: token,
            type: .sms
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        session = nil
    }
}
