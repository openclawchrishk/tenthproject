import SwiftUI

struct ContentView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var authRepository = AuthRepository()

    var body: some View {
        Group {
            if authRepository.session == nil {
                OnboardingFlowView(viewModel: onboardingViewModel)
                    .environmentObject(authRepository)
            } else if authRepository.currentUser == nil {
                OnboardingFlowView(viewModel: onboardingViewModel)
                    .environmentObject(authRepository)
            } else {
                MainTabView()
                    .environmentObject(authRepository)
            }
        }
    }
}

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        NavigationStack {
            switch viewModel.currentStep {
            case .roleSelection:
                RoleSelectionView(viewModel: viewModel)
            case .basicInfo:
                BasicInfoView(viewModel: viewModel)
            case .skillsAndNeeds:
                SkillsAndNeedsView(viewModel: viewModel)
            case .completed:
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.primary, AppColor.secondary)
                    Text("設定完成")
                        .font(.title.bold())
                    Text("你的產業標籤、技能與需求已儲存。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColor.background)
                .onAppear {
                    Task {
                        await viewModel.finalizeOnboarding(auth: auth)
                    }
                }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        TabView {
            ExploreView()
                .tabItem {
                    Label("探索", systemImage: "person.2.fill")
                }

            DeskHubView()
                .tabItem {
                    Label("Desk", systemImage: "briefcase.fill")
                }

            MessagesInboxView()
                .tabItem {
                    Label("訊息", systemImage: "bubble.left.and.bubble.right.fill")
                }

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle.fill")
                }
        }
        // Do not set `.tint` here — it overrides UITabBarAppearance and grays out unselected items.
        .toolbarBackground(AppColor.tabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            TabBarAppearanceConfigurator.apply()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
