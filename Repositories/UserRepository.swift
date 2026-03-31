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

    /// Upserts the full profile row — use for onboarding completion and profile edits.
    func upsertUser(_ user: UserProfile) async throws {
        let payload = UserUpsertPayload(from: user)
        try await client
            .from("users")
            .upsert(payload, onConflict: "id")
            .execute()
    }

    /// Updates only tags and skills fields (same columns as Skills & Needs step).
    func updateSkillsAndNeeds(
        userId: UUID,
        industryTags: [String],
        skills: [String],
        needs: [String]
    ) async throws {
        struct Patch: Encodable {
            let industry_tags: [String]
            let skills: [String]
            let needs: [String]
        }
        let patch = Patch(
            industry_tags: industryTags,
            skills: skills,
            needs: needs
        )
        try await client
            .from("users")
            .update(patch)
            .eq("id", value: userId)
            .execute()
    }
}
