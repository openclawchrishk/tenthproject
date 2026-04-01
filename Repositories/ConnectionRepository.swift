import Foundation
import Supabase

@MainActor
final class ConnectionRepository {
    private let client = SupabaseManager.shared.client

    func fetchConnections(for userId: UUID) async throws -> [Connection] {
        try await fetchConnections(userId: userId)
    }

    func fetchConnections(userId: UUID) async throws -> [Connection] {
        let uid = userId.uuidString
        let filter = "user_a_id.eq.\(uid),user_b_id.eq.\(uid)"
        do {
            return try await client
                .from("connections")
                .select()
                .or(filter)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.fetchConnections")
        }
    }

    func connection(between userId: UUID, and otherId: UUID) async throws -> Connection? {
        let (a, b) = ConnectionPair.normalizedUserIds(userId, otherId)
        do {
            let rows: [Connection] = try await client
                .from("connections")
                .select()
                .eq("user_a_id", value: a)
                .eq("user_b_id", value: b)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.connection")
        }
    }

    func areConnected(_ u1: UUID, _ u2: UUID) async throws -> Bool {
        try await connection(between: u1, and: u2) != nil
    }

    /// Creates a normalized connection row (idempotent if unique constraint exists).
    func createConnection(userId: UUID, peerId: UUID) async throws {
        try await createConnection(inviterId: userId, inviteeId: peerId)
    }

    /// API alias: creates a bidirectional `connections` row from either participant’s perspective.
    func createConnection(inviterId: UUID, inviteeId: UUID) async throws {
        let (a, b) = ConnectionPair.normalizedUserIds(inviterId, inviteeId)
        struct Insert: Encodable {
            let id: UUID
            let user_a_id: UUID
            let user_b_id: UUID
        }
        let row = Insert(id: UUID(), user_a_id: a, user_b_id: b)
        do {
            try await client.from("connections").insert(row).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.createConnection")
        }
    }

    func removeConnection(userId: UUID, peerId: UUID) async throws {
        let (a, b) = ConnectionPair.normalizedUserIds(userId, peerId)
        do {
            try await client
                .from("connections")
                .delete()
                .eq("user_a_id", value: a)
                .eq("user_b_id", value: b)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.removeConnection peer")
        }
    }

    /// Removes a connection by row id; `userId` must be one of the two participants.
    func removeConnection(connectionId: UUID, userId: UUID) async throws {
        let conn: Connection
        do {
            conn = try await client
                .from("connections")
                .select()
                .eq("id", value: connectionId)
                .single()
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.removeConnection by id load")
        }
        guard conn.userAId == userId || conn.userBId == userId else {
            throw RepositoryError.serverError("無權移除此連接")
        }
        do {
            try await client
                .from("connections")
                .delete()
                .eq("id", value: connectionId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.removeConnection by id delete")
        }
    }

    // MARK: - Invites

    /// Pending outgoing connection invite from `from` to `to`, if any.
    func outgoingPendingConnectionInvite(from: UUID, to: UUID) async throws -> ConnectionInvite? {
        do {
            let rows: [ConnectionInvite] = try await client
                .from("connection_invites")
                .select()
                .eq("inviter_id", value: from)
                .eq("invitee_id", value: to)
                .eq("status", value: ConnectionInviteStatus.pending.rawValue)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.outgoingPendingConnectionInvite")
        }
    }

    /// Creates or replaces pending invite (`UNIQUE (inviter_id, invitee_id)`).
    func sendConnectionInvite(from: UUID, to: UUID, message: String?) async throws {
        try await sendConnectionInvite(inviterId: from, inviteeId: to, message: message)
    }

    func sendConnectionInvite(inviterId: UUID, inviteeId: UUID, message: String?) async throws {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let note: String? = {
            guard let t = trimmed, !t.isEmpty else { return nil }
            return String(t.prefix(150))
        }()
        struct Insert: Encodable {
            let id: UUID
            let inviter_id: UUID
            let invitee_id: UUID
            let status: String
            let message: String?
        }
        let row = Insert(
            id: UUID(),
            inviter_id: inviterId,
            invitee_id: inviteeId,
            status: ConnectionInviteStatus.pending.rawValue,
            message: note
        )
        do {
            try await client.from("connection_invites").insert(row).execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.sendConnectionInvite")
        }
    }

    func fetchPendingInvites(for userId: UUID) async throws -> [ConnectionInvite] {
        do {
            return try await client
                .from("connection_invites")
                .select()
                .eq("invitee_id", value: userId)
                .eq("status", value: ConnectionInviteStatus.pending.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.fetchPendingInvites")
        }
    }

    func acceptInvite(inviteId: UUID) async throws {
        struct Patch: Encodable {
            let status: String
        }
        do {
            try await client
                .from("connection_invites")
                .update(Patch(status: ConnectionInviteStatus.accepted.rawValue))
                .eq("id", value: inviteId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.acceptInvite")
        }
    }

    /// Accepts invite and creates bidirectional `connections` row.
    func acceptConnectionInvite(inviteId: UUID, currentUserId: UUID) async throws {
        let inv = try await fetchInvite(id: inviteId)
        guard inv.toUserId == currentUserId else {
            throw RepositoryError.serverError("無法接受此邀請")
        }
        guard inv.status == .pending else { return }
        try await acceptInvite(inviteId: inviteId)
        try await createConnection(userId: inv.fromUserId, peerId: inv.toUserId)
    }

    func declineConnectionInvite(inviteId: UUID, currentUserId: UUID) async throws {
        let inv = try await fetchInvite(id: inviteId)
        guard inv.toUserId == currentUserId else {
            throw RepositoryError.serverError("無法拒絕此邀請")
        }
        guard inv.status == .pending else { return }
        struct Patch: Encodable {
            let status: String
        }
        do {
            try await client
                .from("connection_invites")
                .update(Patch(status: ConnectionInviteStatus.declined.rawValue))
                .eq("id", value: inviteId)
                .execute()
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.declineConnectionInvite")
        }
    }

    func fetchInvite(id: UUID) async throws -> ConnectionInvite {
        do {
            return try await client
                .from("connection_invites")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
        } catch {
            throw RepositoryErrorMapping.map(error, context: "ConnectionRepository.fetchInvite")
        }
    }
}
