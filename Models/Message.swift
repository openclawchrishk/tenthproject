import Foundation

/// DM thread between two users (`conversations` table).
struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    let participantA: UUID
    let participantB: UUID
    var lastMessageAt: Date?
    var createdAt: Date?
    /// Legacy column name support.
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case participantA = "participant_a_id"
        case participantB = "participant_b_id"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case legacyA = "participant_a"
        case legacyB = "participant_b"
    }

    init(
        id: UUID,
        participantA: UUID,
        participantB: UUID,
        lastMessageAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.participantA = participantA
        self.participantB = participantB
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        if let a = try c.decodeIfPresent(UUID.self, forKey: .participantA),
           let b = try c.decodeIfPresent(UUID.self, forKey: .participantB) {
            participantA = a
            participantB = b
        } else {
            participantA = try c.decode(UUID.self, forKey: .legacyA)
            participantB = try c.decode(UUID.self, forKey: .legacyB)
        }
        lastMessageAt = try c.decodeIfPresent(Date.self, forKey: .lastMessageAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(participantA, forKey: .participantA)
        try c.encode(participantB, forKey: .participantB)
        try c.encodeIfPresent(lastMessageAt, forKey: .lastMessageAt)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    func otherUser(than userId: UUID) -> UUID {
        userId == participantA ? participantB : participantA
    }

    var sortDate: Date {
        lastMessageAt ?? updatedAt ?? createdAt ?? .distantPast
    }
}

/// Row in `direct_messages`.
struct DirectMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    var content: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
        case body
    }

    init(id: UUID, conversationId: UUID, senderId: UUID, content: String, createdAt: Date? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        conversationId = try c.decode(UUID.self, forKey: .conversationId)
        senderId = try c.decode(UUID.self, forKey: .senderId)
        if let t = try c.decodeIfPresent(String.self, forKey: .content) {
            content = t
        } else {
            content = try c.decode(String.self, forKey: .body)
        }
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(conversationId, forKey: .conversationId)
        try c.encode(senderId, forKey: .senderId)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    /// Alias for legacy UI copy.
    var body: String { content }
}

struct MessageListItem: Identifiable, Equatable {
    let message: DirectMessage
    let peerDisplayName: String
    let conversation: Conversation

    var id: UUID { message.id }
}
