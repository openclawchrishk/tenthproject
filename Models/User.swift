import Foundation

enum UserRole: String, Codable, CaseIterable {
    case founder = "founder"
    case aspiringFounder = "aspiring_founder"
    case investor = "investor"
    case mentor = "mentor"
    
    var localizedName: String {
        switch self {
        case .founder: return "創辦人"
        case .aspiringFounder: return "有意創業者"
        case .investor: return "投資者"
        case .mentor: return "導師 / 顧問"
        }
    }
}

enum UserLevel: Int, Codable {
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    
    var deskMemberLimit: Int {
        switch self {
        case .level1: return 3
        case .level2: return 5
        case .level3: return 8
        case .level4: return 12
        }
    }
}

enum VerificationStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case interview = "interview"
}

struct User: Identifiable, Codable {
    let id: UUID
    var displayName: String
    var avatarUrl: String?
    var role: UserRole
    var level: UserLevel
    var verificationStatus: VerificationStatus
    var region: String
    var languages: [String]
    var commitmentLevel: String
    var bio: String? // 一句話自我介紹
    var detailedBio: String?
    var industryTags: [String]
    var interestTags: [String]
    var skills: [String]
    var needs: [String]
    var linkedInUrl: String?
    var websiteUrl: String?
    var invitationCode: String
    var profileCompletionRate: Double
    
    var isPremium: Bool {
        level == .level3
    }
    
    var isVerified: Bool {
        verificationStatus == .approved
    }
}
