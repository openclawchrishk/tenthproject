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
