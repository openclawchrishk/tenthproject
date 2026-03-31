import SwiftUI

struct ContentView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var authRepository = AuthRepository()
    
    var body: some View {
        Group {
            if authRepository.session == nil {
                // 這裡應該是 LoginView，現在暫時直接顯示 Onboarding
                OnboardingFlowView(viewModel: onboardingViewModel)
            } else if authRepository.currentUser == nil {
                OnboardingFlowView(viewModel: onboardingViewModel)
            } else {
                MainTabView()
            }
        }
    }
}

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        NavigationView {
            switch viewModel.currentStep {
            case .roleSelection:
                RoleSelectionView(viewModel: viewModel)
            case .basicInfo:
                BasicInfoView(viewModel: viewModel)
            case .skillsAndNeeds:
                // 這裡可以實現第三步
                Text("技能與需求 (開發中)")
                    .onTapGesture {
                        viewModel.proceedToNextStep()
                    }
            case .completed:
                Text("Onboarding 完成！")
                    .onAppear {
                        Task {
                            await viewModel.completeOnboarding()
                        }
                    }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Explore 人")
                .tabItem {
                    Label("探索", systemImage: "person.2")
                }
            
            Text("Explore Desk")
                .tabItem {
                    Label("Desk", systemImage: "briefcase")
                }
            
            Text("訊息")
                .tabItem {
                    Label("訊息", systemImage: "message")
                }
            
            Text("個人資料")
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
