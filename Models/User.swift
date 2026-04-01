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

/// Maps `users.commitment_level` (`fulltime` / `parttime` / `casual`) to onboarding UI copy.
enum CommitmentLevelBridge {
    static func storageValue(from displayOrStorage: String) -> String {
        let t = displayOrStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        switch t {
        case "全職": return "fulltime"
        case "兼職": return "parttime"
        case "只看看": return "casual"
        case "fulltime", "parttime", "casual": return t
        default:
            return "fulltime"
        }
    }

    static func displayValue(from storage: String) -> String {
        switch storage.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "fulltime": return "全職"
        case "parttime": return "兼職"
        case "casual": return "只看看"
        default:
            return storage.isEmpty ? "全職" : storage
        }
    }
}

private enum UserProfileLegacyCodingKeys: String, CodingKey {
    case bio
    case detailed_bio
    case industry_tags
    case interest_tags
    case invitation_code
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
        case bio = "bio_short"
        case detailedBio = "bio_long"
        case industryTags = "industries"
        case interestTags = "interests"
        case skills
        case needs
        case linkedInUrl = "linked_in_url"
        case websiteUrl = "website_url"
        case invitationCode = "referral_code"
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
        let rawCommitment = try c.decodeIfPresent(String.self, forKey: .commitmentLevel) ?? "fulltime"
        commitmentLevel = CommitmentLevelBridge.displayValue(from: rawCommitment)

        let legacy = try? decoder.container(keyedBy: UserProfileLegacyCodingKeys.self)
        if let b = try c.decodeIfPresent(String.self, forKey: .bio) {
            bio = b
        } else {
            bio = try legacy?.decodeIfPresent(String.self, forKey: .bio)
        }
        if let d = try c.decodeIfPresent(String.self, forKey: .detailedBio) {
            detailedBio = d
        } else {
            detailedBio = try legacy?.decodeIfPresent(String.self, forKey: .detailed_bio)
        }
        if let tags = try c.decodeIfPresent([String].self, forKey: .industryTags) {
            industryTags = tags
        } else {
            industryTags = try legacy?.decodeIfPresent([String].self, forKey: .industry_tags) ?? []
        }
        if let tags = try c.decodeIfPresent([String].self, forKey: .interestTags) {
            interestTags = tags
        } else {
            interestTags = try legacy?.decodeIfPresent([String].self, forKey: .interest_tags) ?? []
        }
        skills = try c.decodeIfPresent([String].self, forKey: .skills) ?? []
        needs = try c.decodeIfPresent([String].self, forKey: .needs) ?? []
        linkedInUrl = try c.decodeIfPresent(String.self, forKey: .linkedInUrl)
        websiteUrl = try c.decodeIfPresent(String.self, forKey: .websiteUrl)
        if let code = try c.decodeIfPresent(String.self, forKey: .invitationCode) {
            invitationCode = code
        } else {
            invitationCode = try legacy?.decodeIfPresent(String.self, forKey: .invitation_code) ?? ""
        }
        profileCompletionRate = try c.decodeIfPresent(Double.self, forKey: .profileCompletionRate) ?? 0
        referralCount = try c.decodeIfPresent(Int.self, forKey: .referralCount) ?? 0
    }
}

/// Gamification tier from profile completeness (0–49% / 50–79% / 80–100%), independent of account `UserLevel`.
enum ProfileCompletenessTier: Int, Comparable {
    case starter = 1
    case rising = 2
    case champion = 3

    static func < (lhs: ProfileCompletenessTier, rhs: ProfileCompletenessTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(completeness: Double) -> ProfileCompletenessTier {
        let p = completeness * 100
        if p < 50 { return .starter }
        if p < 80 { return .rising }
        return .champion
    }

    /// Short label under avatar (completeness journey).
    var localizedTitle: String {
        switch self {
        case .starter: return "資料新手"
        case .rising: return "進階創業者"
        case .champion: return "金牌創業者"
        }
    }
}

enum ConnectionMilestone {
    static let thresholds = [10, 25, 50, 100]

    /// Next target strictly after `count`, or nil if at/above last milestone.
    static func next(after count: Int) -> Int? {
        thresholds.first { $0 > count }
    }

    /// Progress 0...1 toward the next milestone; 1.0 when at or past last threshold.
    static func progressFraction(connectionCount: Int) -> Double {
        guard let next = next(after: connectionCount) else { return 1 }
        let prev = thresholds.last { $0 <= connectionCount } ?? 0
        let span = max(1, next - prev)
        return min(1, Double(connectionCount - prev) / Double(span))
    }

    static func milestoneMessageIfReached(newCount: Int, previousCount: Int) -> String? {
        guard newCount > previousCount else { return nil }
        for t in thresholds where newCount >= t && previousCount < t {
            return "恭喜！你已連接 \(t) 位創業者"
        }
        return nil
    }
}

enum ProfileCompleteness {
    /// SF Symbol name for a missing-field title (Chinese keys from `missingItems`).
    static func iconName(forMissingTitle title: String) -> String {
        switch title {
        case "頭像": return "person.crop.circle"
        case "一句簡介": return "text.quote"
        case "詳細介紹": return "doc.text"
        case "LinkedIn": return "link"
        case "網站": return "globe"
        case "興趣標籤": return "tag"
        case "產業標籤": return "building.2"
        case "技能": return "wrench.and.screwdriver"
        case "需求": return "hand.point.left.fill"
        default: return "circle.dotted"
        }
    }

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
    static let pitchMaxLength = 150
    static let bioMaxLength = 500
    static let usernameMaxLength = 30

    static func isValidDisplayName(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= displayNameMaxLength
    }

    static func isValidDeskName(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= deskNameMaxLength
    }

    /// One-line desk pitch: required, max 150 chars.
    static func isValidDeskPitch(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= pitchMaxLength
    }

    static func isValidBioLength(_ raw: String?) -> Bool {
        guard let raw else { return true }
        return raw.count <= bioMaxLength
    }

    /// Public handle: alphanumeric + underscore, ASCII, max length.
    static func isValidUsername(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count <= usernameMaxLength else { return false }
        return t.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) != nil
    }

    /// Empty or valid username (for optional handle).
    static func isValidUsernameOrEmpty(_ raw: String?) -> Bool {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if t.isEmpty { return true }
        return isValidUsername(t)
    }

    /// RFC 4122 UUID string.
    static func isValidUUIDString(_ raw: String) -> Bool {
        UUID(uuidString: raw) != nil
    }

    /// Optional http/https URL string.
    static func isValidOptionalHTTPURLString(_ raw: String?) -> Bool {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if t.isEmpty { return true }
        guard let url = URL(string: t), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }

    /// Password strength for signup (aligned with onboarding UI).
    enum PasswordStrength: Equatable {
        case weak
        case medium
        case strong

        static func evaluate(_ password: String) -> PasswordStrength {
            if password.count < 8 { return .weak }
            let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
            let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
            let hasSymbol = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
            var score = 0
            if password.count >= 12 { score += 1 }
            if hasLetter { score += 1 }
            if hasDigit { score += 1 }
            if hasSymbol { score += 1 }
            if score >= 3 { return .strong }
            if score >= 1 { return .medium }
            return .weak
        }

        var meetsSignUpMinimum: Bool {
            self != .weak
        }

        var strengthLabel: String {
            switch self {
            case .weak: return "弱"
            case .medium: return "中"
            case .strong: return "強"
            }
        }
    }
}

/// Partial update: only non-`nil` fields are encoded (PATCH semantics). Column names match `SUPABASE_SCHEMA.sql`.
struct UserProfilePartialPatch: Encodable {
    var display_name: String?
    var avatar_url: String?
    var bio_short: String?
    var bio_long: String?
    var region: String?
    var languages: [String]?
    var industries: [String]?
    var interests: [String]?
    var skills: [String]?
    var needs: [String]?
    var linked_in_url: String?
    var website_url: String?
    /// Set UI copy (`全職` …) or DB values (`fulltime` …); encoded as canonical `fulltime`/`parttime`/`casual`.
    var commitment_level: String?

    enum CodingKeys: String, CodingKey {
        case display_name, avatar_url, bio_short, bio_long, region, languages
        case industries, interests, skills, needs, linked_in_url, website_url, commitment_level
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(display_name, forKey: .display_name)
        try c.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try c.encodeIfPresent(bio_short, forKey: .bio_short)
        try c.encodeIfPresent(bio_long, forKey: .bio_long)
        try c.encodeIfPresent(region, forKey: .region)
        try c.encodeIfPresent(languages, forKey: .languages)
        try c.encodeIfPresent(industries, forKey: .industries)
        try c.encodeIfPresent(interests, forKey: .interests)
        try c.encodeIfPresent(skills, forKey: .skills)
        try c.encodeIfPresent(needs, forKey: .needs)
        try c.encodeIfPresent(linked_in_url, forKey: .linked_in_url)
        try c.encodeIfPresent(website_url, forKey: .website_url)
        if let commitment_level {
            try c.encode(CommitmentLevelBridge.storageValue(from: commitment_level), forKey: .commitment_level)
        }
    }
}

/// Payload for upserting the `users` row — column names match `SUPABASE_SCHEMA.sql`.
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
    var bio_short: String?
    var bio_long: String?
    var industries: [String]
    var interests: [String]
    var skills: [String]
    var needs: [String]
    var linked_in_url: String?
    var website_url: String?
    var referral_code: String
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
        commitment_level = CommitmentLevelBridge.storageValue(from: user.commitmentLevel)
        bio_short = user.bio
        bio_long = user.detailedBio
        industries = user.industryTags
        interests = user.interestTags
        skills = user.skills
        needs = user.needs
        linked_in_url = user.linkedInUrl
        website_url = user.websiteUrl
        referral_code = user.invitationCode
        profile_completion_rate = user.profileCompleteness
        referral_count = user.referralCount
    }
}
