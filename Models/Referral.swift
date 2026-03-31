import Foundation

struct Referral: Codable, Identifiable, Equatable {
    let id: UUID
    let referrerId: UUID
    let referredUserId: UUID
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case referrerId = "referrer_id"
        case referredUserId = "referred_user_id"
        case createdAt = "created_at"
    }
}
