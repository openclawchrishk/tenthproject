import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MainTabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    /// One-shot: open this segment in Messages (0 DM, 1 notifications, 2 desk invites, 3 connections).
    @Published var messagesSegmentToSelect: Int?
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
                    .onReceive(authRepository.$currentUser) { u in
                        if u != nil {
                            Task { await MainTabBadgeCoordinator.refreshAppIconBadge(auth: authRepository) }
                        }
                    }
            }
        }
        .onOpenURL { url in
            DeskerDeepLinks.handle(url, tabRouter: tabRouter)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var tabRouter: MainTabRouter
    @StateObject private var connectivity = ConnectivityMonitor()
    @State private var inboxBadgeCount = 0
    @State private var deskTabBadgeCount = 0
    @State private var lastTabSwitchAt = Date.distantPast

    private let messagesRepo = MessageRepository()
    private let invitesRepo = InviteRepository()
    private let connectionsRepo = ConnectionRepository()
    private let deskRepo = DeskRepository()

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
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline.weight(.semibold))
            Text("離線 — 顯示上次資料")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppColor.primary.opacity(0.92)))
        .shadow(color: CardChrome.shadowColor, radius: 8, x: 0, y: 3)
    }

    private var iosTabContainer: some View {
        ZStack {
            ExploreView()
                .environmentObject(tabRouter)
                .opacity(tabRouter.selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(tabRouter.selectedTab == 0)
            DeskHubView()
                .environmentObject(tabRouter)
                .opacity(tabRouter.selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(tabRouter.selectedTab == 1)
            MessagesInboxView()
                .environmentObject(tabRouter)
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
        .overlay(alignment: .top) {
            if !connectivity.isConnected {
                offlineBanner
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: connectivity.isConnected)
        .onAppear {
            TabBarAppearanceConfigurator.apply()
            Task { await refreshAllTabBadges() }
            if DeskerUXPreferences.pendingExploreAfterOnboarding {
                DeskerUXPreferences.pendingExploreAfterOnboarding = false
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    tabRouter.selectedTab = 0
                }
            }
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
            Task { await refreshAllTabBadges() }
        }
        .onChange(of: tabRouter.selectedTab) { _, new in
            if new == 2 || new == 1 { Task { await refreshAllTabBadges() } }
        }
    }

    private var iosCustomTabBar: some View {
        HStack(spacing: 0) {
            iosTabButton(0, "探索", "person.2.fill", badge: nil)
            iosTabButton(1, "Desk", "briefcase.fill", badge: deskTabBadgeCount > 0 ? deskTabBadgeCount : nil)
            iosTabButton(2, "訊息", "bubble.left.and.bubble.right.fill", badge: inboxBadgeCount > 0 ? inboxBadgeCount : nil)
            iosTabButton(3, "我的", "person.fill", badge: nil)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(AppColor.tabBarBackground.ignoresSafeArea(edges: .bottom))
    }

    private func refreshAllTabBadges() async {
        await refreshInboxBadge()
        await refreshDeskTabBadge()
        await MainTabBadgeCoordinator.refreshAppIconBadge(auth: auth)
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
        if let pendingConn = try? await connectionsRepo.fetchPendingInvites(for: uid) {
            n += pendingConn.count
        }
        await MainActor.run { inboxBadgeCount = min(99, n) }
    }

    private func refreshDeskTabBadge() async {
        guard let uid = auth.currentUser?.id else {
            await MainActor.run { deskTabBadgeCount = 0 }
            return
        }
        do {
            let apps = try await deskRepo.fetchApplicationsForFounder(founderId: uid)
            let pending = apps.filter { $0.application.status == .pending }.count
            await MainActor.run { deskTabBadgeCount = min(99, pending) }
        } catch {
            await MainActor.run { deskTabBadgeCount = 0 }
        }
    }

    private func iosTabButton(_ index: Int, _ title: String, _ systemImage: String, badge: Int?) -> some View {
        let on = tabRouter.selectedTab == index
        return Button {
            let now = Date()
            guard now.timeIntervalSince(lastTabSwitchAt) >= 0.3 else { return }
            lastTabSwitchAt = now
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
                if let badge, badge > 0 {
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
                .environmentObject(tabRouter)
                .tabItem {
                    Label("探索", systemImage: "person.2.fill")
                }
                .tag(0)

            DeskHubView()
                .environmentObject(tabRouter)
                .tabItem {
                    Label("Desk", systemImage: "briefcase.fill")
                }
                .tag(1)

            MessagesInboxView()
                .environmentObject(tabRouter)
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

// MARK: - Deep links (`desker://`, `https://desker.hk/...`)

enum DeskerDeepLinks {
    @MainActor
    static func handle(_ url: URL, tabRouter: MainTabRouter) {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let isHTTPS = scheme == "https" && (host == "desker.hk" || host == "www.desker.hk")
        let isCustom = scheme == "desker"
        guard isHTTPS || isCustom else { return }

        let path = url.path.lowercased()
        if path.contains("/desk") {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                tabRouter.selectedTab = 1
            }
            return
        }
        if path.contains("/u/") {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                tabRouter.selectedTab = 0
            }
            return
        }
        if path.contains("message") || path.contains("dm") {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                tabRouter.selectedTab = 2
                tabRouter.messagesSegmentToSelect = 0
            }
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            tabRouter.selectedTab = 0
        }
    }
}

enum MainTabBadgeCoordinator {
    @MainActor
    static func refreshAppIconBadge(auth: AuthRepository) async {
        #if os(iOS)
        guard let uid = auth.currentUser?.id else {
            UIApplication.shared.applicationIconBadgeNumber = 0
            return
        }
        let repo = NotificationRepository()
        let n = (try? await repo.unreadCount(userId: uid)) ?? 0
        UIApplication.shared.applicationIconBadgeNumber = min(99, n)
        #endif
    }
}
