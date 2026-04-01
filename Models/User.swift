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

enum UserLevel: Int, Codable, Comparable {
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4

    static func < (lhs: UserLevel, rhs: UserLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var deskMemberLimit: Int {
        switch self {
        case .level1: return 3
        case .level2: return 5
        case .level3: return 8
        case .level4: return 12
        }
    }

    var localizedTitle: String {
        "Level \(rawValue)"
    }
}

/// Official verification (PRD §9). Legacy DB values `approved` / `interview` decode gracefully.
enum VerificationStatus: String, Codable {
    case none = "none"
    case pending = "pending"
    case verifiedInvestor = "verified_investor"
    case verifiedExpert = "verified_expert"
    case rejected = "rejected"

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        switch raw {
        case "none": self = .none
        case "pending": self = .pending
        case "verified_investor": self = .verifiedInvestor
        case "verified_expert": self = .verifiedExpert
        case "rejected": self = .rejected
        case "approved": self = .verifiedExpert
        case "interview": self = .pending
        default: self = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

enum VerificationBadgeStyle {
    case investor
    case expert
}

struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    /// Public handle for `desker.hk/u/{username}` (optional until set).
    var username: String?
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
    /// Cached profile completion 0...1 from server, if present.
    var profileCompletionRate: Double
    /// Number of successful referrals (optional column).
    var referralCount: Int

    var isPremium: Bool {
        level >= .level3
    }

    /// PRD §4.5 — fraction of optional profile fields filled, always in `0...1`.
    var profileCompleteness: Double {
        min(1, max(0, computedProfileCompleteness))
    }

    var verificationBadgeStyle: VerificationBadgeStyle? {
        switch verificationStatus {
        case .verifiedInvestor: return .investor
        case .verifiedExpert: return .expert
        default: return nil
        }
    }

    /// Fraction 0...1 of optional profile fields filled (PRD §4.5).
    var computedProfileCompleteness: Double {
        ProfileCompleteness.fraction(for: self)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
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
        case referralCount = "referral_count"
    }

    init(
        id: UUID,
        username: String? = nil,
        displayName: String,
        avatarUrl: String? = nil,
        role: UserRole,
        level: UserLevel = .level1,
        verificationStatus: VerificationStatus = .none,
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
        profileCompletionRate: Double = 0,
        referralCount: Int = 0
    ) {
        self.id = id
        self.username = username
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
        self.referralCount = referralCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        role = try c.decodeIfPresent(UserRole.self, forKey: .role) ?? .aspiringFounder
        level = try c.decodeIfPresent(UserLevel.self, forKey: .level) ?? .level1
        verificationStatus = try c.decodeIfPresent(VerificationStatus.self, forKey: .verificationStatus) ?? .none
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
        referralCount = try c.decodeIfPresent(Int.self, forKey: .referralCount) ?? 0
    }
}

enum ProfileCompleteness {
    /// Weights optional profile fields equally (0...1).
    static func fraction(for user: UserProfile) -> Double {
        let checks: [Bool] = [
            !(user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            !(user.bio?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            !(user.detailedBio?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            !(user.linkedInUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            !(user.websiteUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
            !user.interestTags.isEmpty,
            !user.industryTags.isEmpty,
            !user.skills.isEmpty,
            !user.needs.isEmpty,
        ]
        let filled = checks.filter(\.self).count
        return checks.isEmpty ? 0 : Double(filled) / Double(checks.count)
    }

    /// (title, action hint) for fields still empty — drives profile completion UX.
    static func missingItems(for user: UserProfile) -> [(String, String)] {
        var out: [(String, String)] = []
        if user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            out.append(("頭像", "上傳或設定頭像"))
        }
        if user.bio?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            out.append(("一句簡介", "填寫 bio，讓人一眼了解你"))
        }
        if user.detailedBio?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            out.append(("詳細介紹", "補充背景與經驗"))
        }
        if user.linkedInUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            out.append(("LinkedIn", "加入專業連結"))
        }
        if user.websiteUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            out.append(("網站", "加入作品或公司網址"))
        }
        if user.interestTags.isEmpty {
            out.append(("興趣標籤", "選擇興趣方向"))
        }
        if user.industryTags.isEmpty {
            out.append(("產業標籤", "選擇產業"))
        }
        if user.skills.isEmpty {
            out.append(("技能", "列出你擅長的領域"))
        }
        if user.needs.isEmpty {
            out.append(("需求", "寫出你正在尋找的資源"))
        }
        return out
    }
}

extension UserProfile: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Shared limits aligned with `SUPABASE_SCHEMA.sql` CHECK constraints.
enum ProfileFieldValidation {
    static let displayNameMaxLength = 50
    static let deskNameMaxLength = 60

    static func isValidDisplayName(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= displayNameMaxLength
    }

    static func isValidDeskName(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= deskNameMaxLength
    }
}

/// Partial update: only non-`nil` fields are encoded (PATCH semantics).
struct UserProfilePartialPatch: Encodable {
    var display_name: String?
    var avatar_url: String?
    var bio: String?
    var detailed_bio: String?
    var region: String?
    var languages: [String]?
    var industry_tags: [String]?
    var interest_tags: [String]?
    var skills: [String]?
    var needs: [String]?
    var linked_in_url: String?
    var website_url: String?
    var commitment_level: String?

    enum CodingKeys: String, CodingKey {
        case display_name, avatar_url, bio, detailed_bio, region, languages
        case industry_tags, interest_tags, skills, needs, linked_in_url, website_url, commitment_level
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(display_name, forKey: .display_name)
        try c.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try c.encodeIfPresent(bio, forKey: .bio)
        try c.encodeIfPresent(detailed_bio, forKey: .detailed_bio)
        try c.encodeIfPresent(region, forKey: .region)
        try c.encodeIfPresent(languages, forKey: .languages)
        try c.encodeIfPresent(industry_tags, forKey: .industry_tags)
        try c.encodeIfPresent(interest_tags, forKey: .interest_tags)
        try c.encodeIfPresent(skills, forKey: .skills)
        try c.encodeIfPresent(needs, forKey: .needs)
        try c.encodeIfPresent(linked_in_url, forKey: .linked_in_url)
        try c.encodeIfPresent(website_url, forKey: .website_url)
        try c.encodeIfPresent(commitment_level, forKey: .commitment_level)
    }
}

/// Payload for upserting the `users` row (snake_case columns).
struct UserUpsertPayload: Encodable {
    let id: UUID
    var username: String?
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
    var referral_count: Int

    init(from user: UserProfile) {
        id = user.id
        username = user.username
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
        profile_completion_rate = user.profileCompleteness
        referral_count = user.referralCount
    }
}
