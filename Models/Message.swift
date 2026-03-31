import Foundation

struct Conversation: Identifiable, Codable, Equatable {
    let id: UUID
    let participantA: UUID
    let participantB: UUID
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case participantA = "participant_a"
        case participantB = "participant_b"
        case updatedAt = "updated_at"
    }

    func otherUser(than userId: UUID) -> UUID {
        userId == participantA ? participantB : participantA
    }
}

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    var body: String
    var createdAt: Date?
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case body
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}

struct MessageListItem: Identifiable, Equatable {
    let message: Message
    let peerDisplayName: String
    let conversation: Conversation

    var id: UUID { message.id }
}
