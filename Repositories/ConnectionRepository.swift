import Foundation
import Supabase

@MainActor
final class ConnectionRepository {
    private let client = SupabaseManager.shared.client

    func fetchConnections(for userId: UUID) async throws -> [Connection] {
        let uid = userId.uuidString
        let filter = "user_a_id.eq.\(uid),user_b_id.eq.\(uid)"
        return try await client
            .from("connections")
            .select()
            .or(filter)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func connection(between userId: UUID, and otherId: UUID) async throws -> Connection? {
        let (a, b) = ConnectionPair.normalizedUserIds(userId, otherId)
        let rows: [Connection] = try await client
            .from("connections")
            .select()
            .eq("user_a_id", value: a)
            .eq("user_b_id", value: b)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func areConnected(_ u1: UUID, _ u2: UUID) async throws -> Bool {
        try await connection(between: u1, and: u2) != nil
    }

    /// Creates a normalized connection row (idempotent if unique constraint exists).
    func createConnection(userId: UUID, peerId: UUID) async throws {
        let (a, b) = ConnectionPair.normalizedUserIds(userId, peerId)
        struct Insert: Encodable {
            let id: UUID
            let user_a_id: UUID
            let user_b_id: UUID
        }
        let row = Insert(id: UUID(), user_a_id: a, user_b_id: b)
        try await client.from("connections").insert(row).execute()
    }

    func removeConnection(userId: UUID, peerId: UUID) async throws {
        let (a, b) = ConnectionPair.normalizedUserIds(userId, peerId)
        try await client
            .from("connections")
            .delete()
            .eq("user_a_id", value: a)
            .eq("user_b_id", value: b)
            .execute()
    }

    // MARK: - Invites

    /// Pending outgoing connection invite from `from` to `to`, if any.
    func outgoingPendingConnectionInvite(from: UUID, to: UUID) async throws -> ConnectionInvite? {
        let rows: [ConnectionInvite] = try await client
            .from("connection_invites")
            .select()
            .eq("from_user_id", value: from)
            .eq("to_user_id", value: to)
            .eq("status", value: ConnectionInviteStatus.pending.rawValue)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func sendConnectionInvite(from: UUID, to: UUID) async throws {
        struct Insert: Encodable {
            let id: UUID
            let from_user_id: UUID
            let to_user_id: UUID
            let status: String
        }
        let row = Insert(
            id: UUID(),
            from_user_id: from,
            to_user_id: to,
            status: ConnectionInviteStatus.pending.rawValue
        )
        try await client.from("connection_invites").insert(row).execute()
    }

    func fetchPendingInvites(for userId: UUID) async throws -> [ConnectionInvite] {
        try await client
            .from("connection_invites")
            .select()
            .eq("to_user_id", value: userId)
            .eq("status", value: ConnectionInviteStatus.pending.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func acceptInvite(inviteId: UUID) async throws {
        struct Patch: Encodable {
            let status: String
        }
        try await client
            .from("connection_invites")
            .update(Patch(status: ConnectionInviteStatus.accepted.rawValue))
            .eq("id", value: inviteId)
            .execute()
    }

    /// Accepts invite and creates bidirectional `connections` row.
    func acceptConnectionInvite(inviteId: UUID, currentUserId: UUID) async throws {
        let inv = try await fetchInvite(id: inviteId)
        guard inv.toUserId == currentUserId else {
            struct Err: LocalizedError { var errorDescription: String? { "無法接受此邀請" } }
            throw Err()
        }
        guard inv.status == .pending else { return }
        try await acceptInvite(inviteId: inviteId)
        try await createConnection(userId: inv.fromUserId, peerId: inv.toUserId)
    }

    func declineConnectionInvite(inviteId: UUID, currentUserId: UUID) async throws {
        let inv = try await fetchInvite(id: inviteId)
        guard inv.toUserId == currentUserId else {
            struct Err: LocalizedError { var errorDescription: String? { "無法拒絕此邀請" } }
            throw Err()
        }
        guard inv.status == .pending else { return }
        struct Patch: Encodable {
            let status: String
        }
        try await client
            .from("connection_invites")
            .update(Patch(status: ConnectionInviteStatus.declined.rawValue))
            .eq("id", value: inviteId)
            .execute()
    }

    func fetchInvite(id: UUID) async throws -> ConnectionInvite {
        try await client
            .from("connection_invites")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
}
