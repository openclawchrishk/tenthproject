import Foundation
import Supabase

@MainActor
final class InviteRepository {
    private let client = SupabaseManager.shared.client

    /// Sends or refreshes an invite. Uses **update-or-insert** so it never hits PostgreSQL duplicate-key errors if `upsert` / `on_conflict` does not match the DB unique constraint.
    func sendOrUpdateInvite(deskId: UUID, inviterId: UUID, inviteeId: UUID, status: InviteStatus = .pending) async throws {
        let rows: [Invite] = try await client
            .from("invites")
            .select()
            .eq("desk_id", value: deskId)
            .eq("invitee_id", value: inviteeId)
            .execute()
            .value

        struct StatusPatch: Encodable {
            let inviter_id: UUID
            let status: String
        }

        if let existing = rows.first {
            try await client
                .from("invites")
                .update(StatusPatch(inviter_id: inviterId, status: status.rawValue))
                .eq("id", value: existing.id)
                .execute()
        } else {
            let payload = InviteUpsertPayload(
                desk_id: deskId,
                inviter_id: inviterId,
                invitee_id: inviteeId,
                status: status.rawValue
            )
            do {
                try await client
                    .from("invites")
                    .insert(payload)
                    .execute()
            } catch {
                // Race: another client inserted between select and insert — resolve by updating.
                let again: [Invite] = try await client
                    .from("invites")
                    .select()
                    .eq("desk_id", value: deskId)
                    .eq("invitee_id", value: inviteeId)
                    .execute()
                    .value
                if let row = again.first {
                    try await client
                        .from("invites")
                        .update(StatusPatch(inviter_id: inviterId, status: status.rawValue))
                        .eq("id", value: row.id)
                        .execute()
                } else {
                    throw error
                }
            }
        }
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
