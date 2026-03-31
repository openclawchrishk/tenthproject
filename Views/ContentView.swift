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
                    Label {
                        Text("探索")
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                    }
                }

            DeskHubView()
                .tabItem {
                    Label {
                        Text("Desk")
                    } icon: {
                        Image(systemName: "briefcase.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                    }
                }

            MessagesInboxView()
                .tabItem {
                    Label {
                        Text("訊息")
                    } icon: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                    }
                }

            ProfileView()
                .tabItem {
                    Label {
                        Text("我的")
                    } icon: {
                        Image(systemName: "person.crop.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                    }
                }
        }
        // Tab bar colors: selected = AppColor.primary, unselected = AppColor.textSecondary via `TabBarAppearanceConfigurator` (avoid `.tint` on TabView).
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
