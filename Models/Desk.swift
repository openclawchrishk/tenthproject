import Foundation

enum DeskStatus: String, Codable {
    case recruiting = "recruiting"
    case full = "full"
    case archived = "archived"
}

struct DeskRole: Codable, Identifiable {
    let id: UUID
    var title: String
    var count: Int
    var skillDescription: String?
}

struct Desk: Identifiable, Codable {
    let id: UUID
    let founderId: UUID
    var name: String
    var pitch: String
    var industryTags: [String]
    var region: String
    var languagePreference: [String]
    var recruitingRoles: [DeskRole]
    var status: DeskStatus
    
    // 私密資訊 (僅獲准入成員可見)
    var detailedDescription: String?
    var fundingNeeds: String?
    var expectations: String?
    
    var currentMemberCount: Int
    var memberLimit: Int {
        recruitingRoles.reduce(1) { $0 + $1.count } // 1 for founder
    }
}

struct DeskApplication: Codable, Identifiable {
    let id: UUID
    let deskId: UUID
    let applicantId: UUID
    var selectedRole: String
    var statement: String
    var status: ApplicationStatus
}

enum ApplicationStatus: String, Codable {
    case pending = "pending"
    case active = "active" // Admit
    case declined = "declined"
    case hold = "hold"
}
