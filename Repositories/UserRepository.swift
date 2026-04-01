import Foundation
import Supabase

enum UserRepositoryError: LocalizedError {
    case notAuthenticated
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "尚未登入"
        case .decodeFailed: return "無法解析使用者資料"
        }
    }
}

@MainActor
final class UserRepository {
    private let client = SupabaseManager.shared.client

    func fetchUser(id: UUID) async throws -> UserProfile {
        let response: UserProfile = try await client
            .from("users")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return response
    }

    /// Paginated list of profiles (e.g. discovery / admin). Ordered by display name.
    func fetchUsers(limit: Int = 200) async throws -> [UserProfile] {
        try await client
            .from("users")
            .select()
            .order("display_name", ascending: true)
            .limit(limit)
            .execute()
            .value
    }

    /// Upserts the full profile row — use for onboarding completion and profile edits.
    func upsertUser(_ user: UserProfile) async throws {
        let payload = UserUpsertPayload(from: user)
        try await client
            .from("users")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    /// Sets verification to pending for manual review (PRD §9).
    func submitVerificationApplication(userId: UUID) async throws {
        try await submitVerificationApplication(
            userId: userId,
            kind: .investor,
            expertDomain: nil,
            documentNote: nil
        )
    }

    enum VerificationApplicationKind: String, Encodable {
        case investor
        case expert
    }

    /// Investor or expert path; expert may set `verification_domain` (e.g. 香港執業律師).
    func submitVerificationApplication(
        userId: UUID,
        kind: VerificationApplicationKind,
        expertDomain: String?,
        documentNote: String?
    ) async throws {
        struct Patch: Encodable {
            let verification_status: String
            let verification_domain: String?
        }
        let domain: String? = {
            guard kind == .expert else { return nil }
            let t = expertDomain?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? nil : t
        }()
        _ = documentNote
        try await client
            .from("users")
            .update(Patch(
                verification_status: VerificationStatus.pending.rawValue,
                verification_domain: domain
            ))
            .eq("id", value: userId)
            .execute()
    }
}
