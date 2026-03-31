import Foundation

/// In-app notification row (`notifications`).
struct AppNotification: Identifiable, Decodable, Equatable {
    let id: UUID
    let userId: UUID
    var type: String
    var title: String
    var body: String
    var data: String?
    var read: Bool
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case body
        case data
        case read
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        read = try c.decodeIfPresent(Bool.self, forKey: .read) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        do {
            data = try c.decodeIfPresent(String.self, forKey: .data)
        } catch {
            data = nil
        }
    }
}

enum AppNotificationType {
    static let inviteReceived = "invite_received"
    static let inviteAccepted = "invite_accepted"
    static let deskApplicationReceived = "desk_application_received"
    static let deskApplicationAccepted = "desk_application_accepted"
    static let deskApplicationRejected = "desk_application_rejected"
    static let dmReceived = "dm_received"
    static let connectionInvite = "connection_invite"
    static let connectionAccepted = "connection_accepted"
}
