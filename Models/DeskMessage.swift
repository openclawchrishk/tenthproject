import Foundation

struct DeskMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let deskId: UUID
    let senderId: UUID
    var content: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deskId = "desk_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
    }
}

struct DeskMember: Identifiable, Codable, Equatable {
    let id: UUID
    let deskId: UUID
    let userId: UUID
    var roleTitle: String?
    var joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deskId = "desk_id"
        case userId = "user_id"
        case roleTitle = "role_title"
        case joinedAt = "joined_at"
    }
}
