import SwiftUI

@MainActor
final class MainTabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
}

struct ContentView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var authRepository = AuthRepository()
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var tabRouter = MainTabRouter()

    var body: some View {
        Group {
            if authRepository.session == nil {
                WelcomeView()
                    .environmentObject(authRepository)
            } else if authRepository.currentUser == nil {
                OnboardingFlowView(viewModel: onboardingViewModel)
                    .environmentObject(authRepository)
            } else {
                MainTabView()
                    .environmentObject(authRepository)
                    .environmentObject(toastCenter)
                    .environmentObject(tabRouter)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var tabRouter: MainTabRouter
    @State private var inboxBadgeCount = 0

    private let messagesRepo = MessageRepository()
    private let invitesRepo = InviteRepository()

    var body: some View {
        Group {
            #if os(iOS)
            iosTabContainer
            #elseif os(macOS)
            macTabContainer
            #endif
        }
        .deskerToastOverlay(toast)
    }

    #if os(iOS)
    private var iosTabContainer: some View {
        ZStack {
            ExploreView()
                .opacity(tabRouter.selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(tabRouter.selectedTab == 0)
            DeskHubView()
                .opacity(tabRouter.selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(tabRouter.selectedTab == 1)
            MessagesInboxView()
                .opacity(tabRouter.selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(tabRouter.selectedTab == 2)
            ProfileView()
                .opacity(tabRouter.selectedTab == 3 ? 1 : 0)
                .allowsHitTesting(tabRouter.selectedTab == 3)
        }
        .animation(.easeInOut(duration: 0.24), value: tabRouter.selectedTab)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            iosCustomTabBar
        }
        .onAppear {
            TabBarAppearanceConfigurator.apply()
            Task { await refreshInboxBadge() }
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
            Task { await refreshInboxBadge() }
        }
        .onChange(of: tabRouter.selectedTab) { _, new in
            if new == 2 { Task { await refreshInboxBadge() } }
        }
    }

    private var iosCustomTabBar: some View {
        HStack(spacing: 0) {
            iosTabButton(0, "探索", "person.2.fill", badge: nil)
            iosTabButton(1, "Desk", "briefcase.fill", badge: nil)
            iosTabButton(2, "訊息", "bubble.left.and.bubble.right.fill", badge: inboxBadgeCount > 0 ? inboxBadgeCount : nil)
            iosTabButton(3, "我的", "person.fill", badge: nil)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(AppColor.tabBarBackground.ignoresSafeArea(edges: .bottom))
    }

    private func refreshInboxBadge() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run { inboxBadgeCount = 0 }
            return
        }
        var n = 0
        if let msgs = try? await messagesRepo.fetchRecentMessagesPreview(for: uid) {
            n += msgs.filter { $0.message.senderId != uid }.count
        }
        if let inv = try? await invitesRepo.fetchInvitesForUser(userId: uid) {
            n += inv.filter { $0.status == .pending && $0.inviteeId == uid }.count
        }
        await MainActor.run { inboxBadgeCount = min(99, n) }
    }

    private func iosTabButton(_ index: Int, _ title: String, _ systemImage: String, badge: Int?) -> some View {
        let on = tabRouter.selectedTab == index
        return Button {
            HapticFeedback.selection()
            withAnimation(.easeInOut(duration: 0.24)) {
                tabRouter.selectedTab = index
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .scaleEffect(on ? 1.1 : 1.0)
                    Text(title)
                        .font(.caption2.weight(on ? .semibold : .medium))
                }
                .foregroundStyle(on ? AppColor.tabBarSelected : AppColor.tabBarUnselected)
                if let badge, badge > 0, index == 2 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColor.error))
                        .offset(x: 10, y: -6)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
    #endif

    #if os(macOS)
    private var macTabContainer: some View {
        TabView(selection: $tabRouter.selectedTab) {
            ExploreView()
                .tabItem {
                    Label("探索", systemImage: "person.2.fill")
                }
                .tag(0)

            DeskHubView()
                .tabItem {
                    Label("Desk", systemImage: "briefcase.fill")
                }
                .tag(1)

            MessagesInboxView()
                .tabItem {
                    Label("訊息", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
    #endif
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
