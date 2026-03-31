import Foundation

enum InviteStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

/// Row in `invites` — unique on (`desk_id`, `invitee_id`) for upsert.
struct Invite: Identifiable, Codable, Equatable {
    let id: UUID
    let deskId: UUID
    let inviterId: UUID
    let inviteeId: UUID
    var status: InviteStatus
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deskId = "desk_id"
        case inviterId = "inviter_id"
        case inviteeId = "invitee_id"
        case status
        case createdAt = "created_at"
    }
}

struct InviteUpsertPayload: Encodable {
    let desk_id: UUID
    let inviter_id: UUID
    let invitee_id: UUID
    let status: String
}
