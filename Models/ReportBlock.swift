import Foundation

enum ReportTargetType: String, Codable {
    case user
    case desk
    case message
    case deskMessage = "desk_message"
    case directMessage = "direct_message"
}

struct ReportDraft: Equatable {
    var targetType: ReportTargetType
    var targetId: UUID
    var reason: String
}
