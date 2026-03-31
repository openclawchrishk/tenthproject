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

struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var avatarUrl: String?
    var role: UserRole
    var level: UserLevel
    var verificationStatus: VerificationStatus
    var region: String
    var languages: [String]
    var commitmentLevel: String
    var bio: String?
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

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case role
        case level
        case verificationStatus = "verification_status"
        case region
        case languages
        case commitmentLevel = "commitment_level"
        case bio
        case detailedBio = "detailed_bio"
        case industryTags = "industry_tags"
        case interestTags = "interest_tags"
        case skills
        case needs
        case linkedInUrl = "linked_in_url"
        case websiteUrl = "website_url"
        case invitationCode = "invitation_code"
        case profileCompletionRate = "profile_completion_rate"
    }

    init(
        id: UUID,
        displayName: String,
        avatarUrl: String? = nil,
        role: UserRole,
        level: UserLevel = .level1,
        verificationStatus: VerificationStatus = .pending,
        region: String = "HK",
        languages: [String] = ["廣東話"],
        commitmentLevel: String = "全職",
        bio: String? = nil,
        detailedBio: String? = nil,
        industryTags: [String] = [],
        interestTags: [String] = [],
        skills: [String] = [],
        needs: [String] = [],
        linkedInUrl: String? = nil,
        websiteUrl: String? = nil,
        invitationCode: String = "",
        profileCompletionRate: Double = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.role = role
        self.level = level
        self.verificationStatus = verificationStatus
        self.region = region
        self.languages = languages
        self.commitmentLevel = commitmentLevel
        self.bio = bio
        self.detailedBio = detailedBio
        self.industryTags = industryTags
        self.interestTags = interestTags
        self.skills = skills
        self.needs = needs
        self.linkedInUrl = linkedInUrl
        self.websiteUrl = websiteUrl
        self.invitationCode = invitationCode
        self.profileCompletionRate = profileCompletionRate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        role = try c.decodeIfPresent(UserRole.self, forKey: .role) ?? .aspiringFounder
        level = try c.decodeIfPresent(UserLevel.self, forKey: .level) ?? .level1
        verificationStatus = try c.decodeIfPresent(VerificationStatus.self, forKey: .verificationStatus) ?? .pending
        region = try c.decodeIfPresent(String.self, forKey: .region) ?? "HK"
        languages = try c.decodeIfPresent([String].self, forKey: .languages) ?? ["廣東話"]
        commitmentLevel = try c.decodeIfPresent(String.self, forKey: .commitmentLevel) ?? "全職"
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        detailedBio = try c.decodeIfPresent(String.self, forKey: .detailedBio)
        industryTags = try c.decodeIfPresent([String].self, forKey: .industryTags) ?? []
        interestTags = try c.decodeIfPresent([String].self, forKey: .interestTags) ?? []
        skills = try c.decodeIfPresent([String].self, forKey: .skills) ?? []
        needs = try c.decodeIfPresent([String].self, forKey: .needs) ?? []
        linkedInUrl = try c.decodeIfPresent(String.self, forKey: .linkedInUrl)
        websiteUrl = try c.decodeIfPresent(String.self, forKey: .websiteUrl)
        invitationCode = try c.decodeIfPresent(String.self, forKey: .invitationCode) ?? ""
        profileCompletionRate = try c.decodeIfPresent(Double.self, forKey: .profileCompletionRate) ?? 0
    }
}

/// Payload for upserting the `users` row (snake_case columns).
struct UserUpsertPayload: Encodable {
    let id: UUID
    var display_name: String
    var avatar_url: String?
    var role: String
    var level: Int
    var verification_status: String
    var region: String
    var languages: [String]
    var commitment_level: String
    var bio: String?
    var detailed_bio: String?
    var industry_tags: [String]
    var interest_tags: [String]
    var skills: [String]
    var needs: [String]
    var linked_in_url: String?
    var website_url: String?
    var invitation_code: String
    var profile_completion_rate: Double

    init(from user: UserProfile) {
        id = user.id
        display_name = user.displayName
        avatar_url = user.avatarUrl
        role = user.role.rawValue
        level = user.level.rawValue
        verification_status = user.verificationStatus.rawValue
        region = user.region
        languages = user.languages
        commitment_level = user.commitmentLevel
        bio = user.bio
        detailed_bio = user.detailedBio
        industry_tags = user.industryTags
        interest_tags = user.interestTags
        skills = user.skills
        needs = user.needs
        linked_in_url = user.linkedInUrl
        website_url = user.websiteUrl
        invitation_code = user.invitationCode
        profile_completion_rate = user.profileCompletionRate
    }
}
