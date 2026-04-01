import Foundation

enum DeskStatus: String, Codable {
    case recruiting = "recruiting"
    case full = "full"
    case archived = "archived"
}

struct DeskRole: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var count: Int
    var skillDescription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case count
        case skillDescription = "skill_description"
        case skillsDescription = "skills_description"
    }

    init(id: UUID = UUID(), title: String, count: Int, skillDescription: String? = nil) {
        self.id = id
        self.title = title
        self.count = count
        self.skillDescription = skillDescription
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        if let s = try c.decodeIfPresent(String.self, forKey: .skillsDescription) {
            skillDescription = s
        } else {
            skillDescription = try c.decodeIfPresent(String.self, forKey: .skillDescription)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(count, forKey: .count)
        try c.encodeIfPresent(skillDescription, forKey: .skillsDescription)
    }
}

struct Desk: Identifiable, Codable, Equatable {
    let id: UUID
    let founderId: UUID
    var name: String
    var pitch: String
    var industryTags: [String]
    var region: String
    var languagePreference: [String]
    var recruitingRoles: [DeskRole]
    var status: DeskStatus
    var detailedDescription: String?
    var fundingNeeds: String?
    var expectations: String?
    var currentMemberCount: Int
    /// Stored as ISO8601 in Supabase `timestamptz`
    var createdAt: Date?

    var memberLimit: Int {
        max(1, recruitingRoles.reduce(1) { $0 + $1.count })
    }

    var skillsSummary: String {
        let parts = recruitingRoles.map { role in
            if let s = role.skillDescription, !s.isEmpty { return "\(role.title): \(s)" }
            return role.title
        }
        return parts.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case founderId = "founder_id"
        case name
        case pitch
        case industryTags = "industry_tags"
        case region
        case languagePreference = "language_preference"
        case recruitingRoles = "recruiting_roles"
        case status
        case detailedDescription = "detailed_description"
        case fundingNeeds = "funding_needs"
        case expectations
        case currentMemberCount = "current_member_count"
        case createdAt = "created_at"
    }

    init(
        id: UUID,
        founderId: UUID,
        name: String,
        pitch: String,
        industryTags: [String],
        region: String,
        languagePreference: [String],
        recruitingRoles: [DeskRole],
        status: DeskStatus,
        detailedDescription: String? = nil,
        fundingNeeds: String? = nil,
        expectations: String? = nil,
        currentMemberCount: Int,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.founderId = founderId
        self.name = name
        self.pitch = pitch
        self.industryTags = industryTags
        self.region = region
        self.languagePreference = languagePreference
        self.recruitingRoles = recruitingRoles
        self.status = status
        self.detailedDescription = detailedDescription
        self.fundingNeeds = fundingNeeds
        self.expectations = expectations
        self.currentMemberCount = currentMemberCount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        founderId = try c.decode(UUID.self, forKey: .founderId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        pitch = try c.decodeIfPresent(String.self, forKey: .pitch) ?? ""
        industryTags = try c.decodeIfPresent([String].self, forKey: .industryTags) ?? []
        region = try c.decodeIfPresent(String.self, forKey: .region) ?? "HK"
        languagePreference = try c.decodeIfPresent([String].self, forKey: .languagePreference) ?? []
        recruitingRoles = try c.decodeIfPresent([DeskRole].self, forKey: .recruitingRoles) ?? []
        status = try c.decodeIfPresent(DeskStatus.self, forKey: .status) ?? .recruiting
        detailedDescription = try c.decodeIfPresent(String.self, forKey: .detailedDescription)
        fundingNeeds = try c.decodeIfPresent(String.self, forKey: .fundingNeeds)
        expectations = try c.decodeIfPresent(String.self, forKey: .expectations)
        currentMemberCount = try c.decodeIfPresent(Int.self, forKey: .currentMemberCount) ?? 1
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct DeskApplication: Codable, Identifiable, Equatable {
    let id: UUID
    let deskId: UUID
    let applicantId: UUID
    var selectedRole: String
    var statement: String
    var status: ApplicationStatus

    enum CodingKeys: String, CodingKey {
        case id
        case deskId = "desk_id"
        case applicantId = "applicant_id"
        case selectedRole = "selected_role"
        case statement
        case status
    }
}

/// Matches `desk_applications.status` in Supabase: `pending` / `active` (accepted) / `rejected` / `hold`.
enum ApplicationStatus: Equatable, Codable {
    case pending
    case accepted
    case declined
    case hold

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        switch s {
        case "pending": self = .pending
        case "accepted", "active": self = .accepted
        case "declined", "rejected": self = .declined
        case "hold": self = .hold
        default:
            self = .pending
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(databaseValue)
    }

    /// Persisted enum string for `desk_applications.status`.
    var databaseValue: String {
        switch self {
        case .pending: return "pending"
        case .accepted: return "active"
        case .declined: return "rejected"
        case .hold: return "hold"
        }
    }
}

/// Application row plus resolved applicant name for founder UI.
struct DeskApplicationItem: Identifiable, Equatable {
    let application: DeskApplication
    let applicantDisplayName: String
    let deskName: String
    /// Resolved from `users.avatar_url` when available.
    let applicantAvatarUrl: String?

    var id: UUID { application.id }
}
