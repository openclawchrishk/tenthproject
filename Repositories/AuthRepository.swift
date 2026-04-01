import Foundation
import Supabase

private struct CheckEmailRegisteredParams: Encodable {
    let p_email: String
}

@MainActor
final class AuthRepository: ObservableObject {
    @Published var currentUser: UserProfile?
    @Published var session: Session?

    private let client = SupabaseManager.shared.client
    private var authListenerTask: Task<Void, Never>?

    init() {
        authListenerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await (_, session) in SupabaseManager.shared.client.auth.authStateChanges {
                self.session = session
                if let session {
                    do {
                        try await self.fetchUserProfile(userId: session.user.id)
                    } catch {
                        repositoryLogger.error("Auth authStateChanges fetchUserProfile: \(error.localizedDescription, privacy: .public)")
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
        do {
            let profile: UserProfile = try await client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            self.currentUser = profile
        } catch {
            throw RepositoryErrorMapping.map(error, context: "AuthRepository.fetchUserProfile")
        }
    }

    func refreshProfile() async {
        guard let uid = session?.user.id else { return }
        do {
            try await fetchUserProfile(userId: uid)
        } catch {
            repositoryLogger.error("refreshProfile: \(error.localizedDescription, privacy: .public)")
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        do {
            _ = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
            )
        } catch {
            throw RepositoryErrorMapping.map(error, context: "AuthRepository.signInWithApple")
        }
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

    func signInWithEmailOTP(email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
    }

    func verifyEmailOTP(email: String, token: String) async throws {
        _ = try await client.auth.verifyOTP(
            email: email,
            token: token,
            type: .email
        )
    }

    /// Email/password sign-in using Supabase `auth.users` (GoTrue).
    func signInWithEmail(email: String, password: String) async throws -> AuthResponse {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return .session(session)
        } catch {
            throw RepositoryErrorMapping.map(error, context: "AuthRepository.signInWithEmail")
        }
    }

    /// Registers a new email user; `display_name` is stored in user metadata.
    func signUpWithEmail(email: String, password: String, displayName: String) async throws -> AuthResponse {
        let data: [String: AnyJSON] = ["display_name": .string(displayName)]
        do {
            return try await client.auth.signUp(email: email, password: password, data: data)
        } catch {
            throw RepositoryErrorMapping.map(error, context: "AuthRepository.signUpWithEmail")
        }
    }

    func resetPassword(email: String) async throws {
        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            throw RepositoryErrorMapping.map(error, context: "AuthRepository.resetPassword")
        }
    }

    /// Current Supabase session wrapped as ``AuthResponse``, if any.
    func getCurrentUser() -> AuthResponse? {
        guard let session = client.auth.currentSession else { return nil }
        return .session(session)
    }

    /// Requires `public.check_email_registered` in the database (see `SUPABASE_SCHEMA.sql`).
    func checkEmailRegistered(email: String) async throws -> Bool {
        do {
            return try await client
                .rpc("check_email_registered", params: CheckEmailRegisteredParams(p_email: email))
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "AuthRepository.checkEmailRegistered")
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            repositoryLogger.error("signOut: \(error.localizedDescription, privacy: .public)")
            throw RepositoryErrorMapping.map(error, context: "AuthRepository.signOut")
        }
        currentUser = nil
        session = nil
        Task { await ImageCache.shared.removeAll() }
    }
}
