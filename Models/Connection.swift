import Foundation

enum ConnectionInviteStatus: String, Codable {
    case pending
    case accepted
    case declined
}

/// Bidirectional link between two users (`connections`).
struct Connection: Identifiable, Codable, Equatable {
    let id: UUID
    let userAId: UUID
    let userBId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userAId = "user_a_id"
        case userBId = "user_b_id"
        case createdAt = "created_at"
    }

    func otherUser(than userId: UUID) -> UUID {
        userId == userAId ? userBId : userAId
    }
}

/// Invite before a `Connection` exists (`connection_invites`).
struct ConnectionInvite: Identifiable, Codable, Equatable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    /// Optional personal note from inviter (PRD §8).
    var message: String?
    var status: ConnectionInviteStatus
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "inviter_id"
        case toUserId = "invitee_id"
        case message
        case status
        case createdAt = "created_at"
    }
}

enum ConnectionPair {
    static func normalizedUserIds(_ u1: UUID, _ u2: UUID) -> (UUID, UUID) {
        u1.uuidString.lowercased() <= u2.uuidString.lowercased() ? (u1, u2) : (u2, u1)
    }
}
