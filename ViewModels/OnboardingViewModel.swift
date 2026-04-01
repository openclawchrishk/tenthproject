import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var selectedRole: UserRole?
    @Published var displayName: String = ""
    @Published var region: String = "HK"
    @Published var selectedLanguages: Set<String> = ["廣東話"]
    @Published var commitmentLevel: String = "全職"

    @Published var industryTags: Set<String> = []
    @Published var skills: Set<String> = []
    @Published var needs: Set<String> = []

    /// Local avatar image data during onboarding (optional preview).
    @Published var avatarImageData: Data?

    @Published var currentStep: OnboardingStep = .roleSelection
    /// Drives asymmetric slide transitions in `OnboardingFlowView` (forward vs back).
    @Published private(set) var lastStepNavigationWasForward: Bool = true

    static let languageOptions = ["廣東話", "普通話", "英文", "日本語", "其他"]

    static let industryOptions = [
        "金融科技", "教育", "醫療健康", "電商", "SaaS", "AI / 數據", "區塊鏈", "消費品牌",
    ]
    static let skillOptions = [
        "產品", "設計", "前端", "後端", "市場", "營運", "投資", "法律",
    ]
    static let needOptions = [
        "技術合夥人", "資金", "導師", "市場渠道", "招聘", "辦公空間",
    ]

    static let interestOptions = [
        "早期投資", "產品合作", "導師交流", "招聘", "社群活動", "出海", "政府資助", "大灣區機會",
    ]

    enum OnboardingStep: Hashable {
        case roleSelection
        case basicInfo
        case skillsAndNeeds
        case completed
    }

    private let userRepo = UserRepository()

    func proceedToNextStep() {
        lastStepNavigationWasForward = true
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            switch currentStep {
            case .roleSelection:
                currentStep = .basicInfo
            case .basicInfo:
                currentStep = .skillsAndNeeds
            case .skillsAndNeeds:
                currentStep = .completed
            case .completed:
                break
            }
        }
    }

    func goToPreviousStep() {
        lastStepNavigationWasForward = false
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            switch currentStep {
            case .roleSelection, .completed:
                break
            case .basicInfo:
                currentStep = .roleSelection
            case .skillsAndNeeds:
                currentStep = .basicInfo
            }
        }
    }

    /// Persists industry / skills / needs and merges with existing `users` row if present.
    func persistSkillsAndNeeds(auth: AuthRepository) async throws {
        guard let session = auth.session else {
            throw RepositoryError.notAuthenticated
        }
        let uid = session.user.id

        let merged: UserProfile
        if let existing = try? await userRepo.fetchUser(id: uid) {
            merged = existing
        } else {
            merged = UserProfile(
                id: uid,
                displayName: displayName.isEmpty ? "用戶" : displayName,
                role: selectedRole ?? .aspiringFounder,
                region: region,
                languages: Array(selectedLanguages),
                commitmentLevel: commitmentLevel
            )
        }

        var updated = merged
        if !displayName.isEmpty { updated.displayName = displayName }
        if let r = selectedRole { updated.role = r }
        updated.region = region
        updated.languages = Array(selectedLanguages)
        updated.commitmentLevel = commitmentLevel
        updated.industryTags = Array(industryTags).sorted()
        updated.skills = Array(skills).sorted()
        updated.needs = Array(needs).sorted()
        if updated.invitationCode.isEmpty {
            updated.invitationCode = String(uid.uuidString.prefix(8)).uppercased()
        }

        try await userRepo.upsertUser(updated)
        try await auth.fetchUserProfile(userId: uid)
    }

    func finalizeOnboarding(auth: AuthRepository) async {
        await auth.refreshProfile()
    }
}
