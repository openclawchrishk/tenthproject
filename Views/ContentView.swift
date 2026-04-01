import SwiftUI

struct ContentView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var authRepository = AuthRepository()

    var body: some View {
        Group {
            if authRepository.session == nil {
                // No session - show welcome/login screen
                WelcomeView()
                    .environmentObject(authRepository)
            } else if authRepository.currentUser == nil {
                // Has session but no profile - run onboarding
                OnboardingFlowView(viewModel: onboardingViewModel)
                    .environmentObject(authRepository)
            } else {
                // Has session and profile - show main app
                MainTabView()
                    .environmentObject(authRepository)
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
        #if os(iOS)
        .toolbarBackground(AppColor.tabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            TabBarAppearanceConfigurator.apply()
        }
        #endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
