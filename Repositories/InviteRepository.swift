import Foundation
import Supabase

@MainActor
final class InviteRepository {
    private let client = SupabaseManager.shared.client

    /// Sends a Desk 邀請（或更新既有待處理邀請）。語意同 `sendOrUpdateInvite`。
    func sendInvite(deskId: UUID, inviterId: UUID, inviteeId: UUID) async throws {
        try await sendOrUpdateInvite(deskId: deskId, inviterId: inviterId, inviteeId: inviteeId, status: .pending)
    }

    /// 被邀請者接受邀請。
    func acceptInvite(inviteId: UUID, actingUserId: UUID) async throws {
        try await setInviteResponse(inviteId: inviteId, actingUserId: actingUserId, newStatus: .accepted)
    }

    /// 被邀請者拒絕邀請。
    func declineInvite(inviteId: UUID, actingUserId: UUID) async throws {
        try await setInviteResponse(inviteId: inviteId, actingUserId: actingUserId, newStatus: .declined)
    }

    private func setInviteResponse(inviteId: UUID, actingUserId: UUID, newStatus: InviteStatus) async throws {
        let invite: Invite
        do {
            invite = try await client
                .from("invites")
                .select()
                .eq("id", value: inviteId)
                .single()
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "InviteRepository.setInviteResponse load")
        }
        guard invite.inviteeId == actingUserId else {
            throw RepositoryError.serverError("只有被邀請者可以回覆此邀請")
        }
        guard invite.status == .pending else { throw RepositoryError.serverError("此邀請已處理") }

        try await updateInviteStatus(inviteId: inviteId, status: newStatus)
    }

    func updateInviteStatus(inviteId: UUID, status: InviteStatus) async throws {
        struct StatusPatch: Encodable {
            let status: String
        }
        do {
            try await client
                .from("invites")
                .update(StatusPatch(status: status.rawValue))
                .eq("id", value: inviteId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "InviteRepository.updateInviteStatus")
        }
    }

    func fetchInvitesForDesk(deskId: UUID) async throws -> [Invite] {
        do {
            return try await client
                .from("invites")
                .select()
                .eq("desk_id", value: deskId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "InviteRepository.fetchInvitesForDesk")
        }
    }

    /// Sends or refreshes an invite. Uses **update-or-insert** so it never hits PostgreSQL duplicate-key errors if `upsert` / `on_conflict` does not match the DB unique constraint.
    func sendOrUpdateInvite(deskId: UUID, inviterId: UUID, inviteeId: UUID, status: InviteStatus = .pending) async throws {
        let rows: [Invite]
        do {
            rows = try await client
                .from("invites")
                .select()
                .eq("desk_id", value: deskId)
                .eq("invitee_id", value: inviteeId)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "InviteRepository.sendOrUpdateInvite select")
        }

        struct StatusPatch: Encodable {
            let inviter_id: UUID
            let status: String
        }

        if let existing = rows.first {
            do {
                try await client
                    .from("invites")
                    .update(StatusPatch(inviter_id: inviterId, status: status.rawValue))
                    .eq("id", value: existing.id)
                    .execute()
            } catch {
                throw RepositoryErrorMapping.map(error, context: "InviteRepository.sendOrUpdateInvite update")
            }
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
                let again: [Invite]
                do {
                    again = try await client
                        .from("invites")
                        .select()
                        .eq("desk_id", value: deskId)
                        .eq("invitee_id", value: inviteeId)
                        .execute()
                        .value
                } catch {
                    throw RepositoryErrorMapping.map(error, context: "InviteRepository.sendOrUpdateInvite race select")
                }
                if let row = again.first {
                    do {
                        try await client
                            .from("invites")
                            .update(StatusPatch(inviter_id: inviterId, status: status.rawValue))
                            .eq("id", value: row.id)
                            .execute()
                    } catch {
                        throw RepositoryErrorMapping.map(error, context: "InviteRepository.sendOrUpdateInvite race update")
                    }
                } else {
                    throw RepositoryErrorMapping.map(error, context: "InviteRepository.sendOrUpdateInvite insert")
                }
            }
        }
    }

    /// Existing invite for this desk + invitee (any status), if present.
    func fetchInvite(deskId: UUID, inviteeId: UUID) async throws -> Invite? {
        do {
            let rows: [Invite] = try await client
                .from("invites")
                .select()
                .eq("desk_id", value: deskId)
                .eq("invitee_id", value: inviteeId)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw RepositoryErrorMapping.map(error, context: "InviteRepository.fetchInvite")
        }
    }

    func fetchInvitesForUser(userId: UUID) async throws -> [Invite] {
        let asInvitee: [Invite]
        let asInviter: [Invite]
        do {
            asInvitee = try await client
                .from("invites")
                .select()
                .eq("invitee_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            asInviter = try await client
                .from("invites")
                .select()
                .eq("inviter_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "InviteRepository.fetchInvitesForUser")
        }
        var byId: [UUID: Invite] = [:]
        for i in asInvitee + asInviter { byId[i.id] = i }
        return byId.values.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }
}
