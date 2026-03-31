import Foundation
import Supabase

@MainActor
final class InviteRepository {
    private let client = SupabaseManager.shared.client

    /// Sends or refreshes an invite. Uses **upsert** on (`desk_id`, `invitee_id`) so re-inviting the same user updates the row instead of failing with a duplicate key.
    func sendOrUpdateInvite(deskId: UUID, inviterId: UUID, inviteeId: UUID, status: InviteStatus = .pending) async throws {
        let payload = InviteUpsertPayload(
            desk_id: deskId,
            inviter_id: inviterId,
            invitee_id: inviteeId,
            status: status.rawValue
        )
        try await client
            .from("invites")
            .upsert(payload, onConflict: "desk_id,invitee_id")
            .execute()
    }

    func fetchInvitesForUser(userId: UUID) async throws -> [Invite] {
        let asInvitee: [Invite] = try await client
            .from("invites")
            .select()
            .eq("invitee_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        let asInviter: [Invite] = try await client
            .from("invites")
            .select()
            .eq("inviter_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        var byId: [UUID: Invite] = [:]
        for i in asInvitee + asInviter { byId[i.id] = i }
        return byId.values.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }
}
