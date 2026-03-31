import SwiftUI

class OnboardingViewModel: ObservableObject {
    @Published var selectedRole: UserRole?
    @Published var displayName: String = ""
    @Published var avatarImage: UIImage?
    @Published var region: String = "HK"
    @Published var selectedLanguages: Set<String> = ["廣東話"]
    @Published var commitmentLevel: String = "全職"
    
    @Published var currentStep: OnboardingStep = .roleSelection
    
    enum OnboardingStep {
        case roleSelection
        case basicInfo
        case skillsAndNeeds
        case completed
    }
    
    func proceedToNextStep() {
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
    
    func completeOnboarding() async {
        // 調用 Repository 提交資料到 Supabase
        // try await userRepository.updateProfile(...)
    }
}
