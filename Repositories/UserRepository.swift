import Foundation
import Supabase

@MainActor
final class UserRepository {
    private let client = SupabaseManager.shared.client

    func fetchUser(id: UUID) async throws -> UserProfile {
        do {
            let response: UserProfile = try await client
                .from("users")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            return response
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.fetchUser id=\(id)")
        }
    }

    /// Exact match on `username` (for public profile URLs `/u/{handle}`).
    func fetchUserByUsername(_ username: String) async throws -> UserProfile? {
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !u.isEmpty else { return nil }
        do {
            let rows: [UserProfile] = try await client
                .from("users")
                .select()
                .eq("username", value: u)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.fetchUserByUsername")
        }
    }

    /// Batch-load profiles by id (deduped); empty `ids` returns `[]`.
    func fetchUsersByIds(_ ids: [UUID]) async throws -> [UserProfile] {
        let unique = Array(Set(ids))
        guard !unique.isEmpty else { return [] }
        do {
            let rows: [UserProfile] = try await client
                .from("users")
                .select()
                .in("id", values: unique)
                .execute()
                .value
            return rows
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.fetchUsersByIds count=\(unique.count)")
        }
    }

    /// Paginated list of profiles (e.g. discovery / admin). Ordered by display name.
    func fetchUsers(limit: Int = 200) async throws -> [UserProfile] {
        do {
            return try await client
                .from("users")
                .select()
                .order("display_name", ascending: true)
                .limit(limit)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.fetchUsers limit=\(limit)")
        }
    }

    /// Search by display name or username (case-insensitive substring).
    func searchUsers(query: String, limit: Int = 50) async throws -> [UserProfile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let escaped = q
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let pattern = "%\(escaped)%"
        do {
            let filter = "display_name.ilike.\(pattern),username.ilike.\(pattern)"
            return try await client
                .from("users")
                .select()
                .or(filter)
                .order("display_name", ascending: true)
                .limit(limit)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.searchUsers")
        }
    }

    /// Upserts the full profile row — use for onboarding completion and profile edits.
    func upsertUser(_ user: UserProfile) async throws {
        guard ProfileFieldValidation.isValidDisplayName(user.displayName) else {
            throw RepositoryError.serverError("顯示名稱須為 1–\(ProfileFieldValidation.displayNameMaxLength) 字")
        }
        let payload = UserUpsertPayload(from: user)
        do {
            try await client
                .from("users")
                .upsert(payload, onConflict: "id")
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.upsertUser id=\(user.id)")
        }
    }

    /// Partial profile update (only set fields are sent).
    func updateUserProfile(userId: UUID, patch: UserProfilePartialPatch) async throws {
        if let name = patch.display_name {
            guard ProfileFieldValidation.isValidDisplayName(name) else {
                throw RepositoryError.serverError("顯示名稱須為 1–\(ProfileFieldValidation.displayNameMaxLength) 字")
            }
        }
        do {
            try await client
                .from("users")
                .update(patch)
                .eq("id", value: userId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.updateUserProfile id=\(userId)")
        }
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
        do {
            try await client
                .from("users")
                .update(Patch(
                    verification_status: VerificationStatus.pending.rawValue,
                    verification_domain: domain
                ))
                .eq("id", value: userId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "UserRepository.submitVerificationApplication")
        }
    }
}
