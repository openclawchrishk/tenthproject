import Foundation
import Supabase

@MainActor
final class ReportBlockRepository {
    private let client = SupabaseManager.shared.client

    func submitReport(_ draft: ReportDraft, reporterId: UUID) async throws {
        struct Insert: Encodable {
            let id: UUID
            let reporter_id: UUID
            let target_type: String
            let target_id: UUID
            let reason: String
        }
        let row = Insert(
            id: UUID(),
            reporter_id: reporterId,
            target_type: draft.targetType.rawValue,
            target_id: draft.targetId,
            reason: draft.reason
        )
        do {
            try await client.from("reports").insert(row).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ReportBlockRepository.submitReport")
        }
    }

    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        struct Insert: Encodable {
            let id: UUID
            let blocker_id: UUID
            let blocked_id: UUID
        }
        let row = Insert(id: UUID(), blocker_id: blockerId, blocked_id: blockedId)
        do {
            try await client.from("blocked_users").insert(row).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ReportBlockRepository.blockUser")
        }
    }

    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        do {
            try await client
                .from("blocked_users")
                .delete()
                .eq("blocker_id", value: blockerId)
                .eq("blocked_id", value: blockedId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ReportBlockRepository.unblockUser")
        }
    }

    func isBlocked(blockerId: UUID, candidateId: UUID) async throws -> Bool {
        struct Row: Decodable {
            let id: UUID
        }
        do {
            let rows: [Row] = try await client
                .from("blocked_users")
                .select("id")
                .eq("blocker_id", value: blockerId)
                .eq("blocked_id", value: candidateId)
                .limit(1)
                .execute()
                .value
            return !rows.isEmpty
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ReportBlockRepository.isBlocked")
        }
    }
}
