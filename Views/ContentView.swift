import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

@MainActor
final class MainTabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    /// One-shot: open this segment in Messages (0 DM, 1 notifications, 2 desk invites, 3 connections).
    @Published var messagesSegmentToSelect: Int?
    /// Deep link: push `DeskDetailView` on Desk tab.
    @Published var pendingOpenDeskId: UUID?
    /// Deep link: show public profile sheet on Explore (by user id).
    @Published var pendingExploreProfileUserId: UUID?
    /// Deep link: resolve username then show profile on Explore (`/u/{username}`).
    @Published var pendingExploreUsername: String?
    /// Deep link: open DM for this conversation id (Messages → 私訊 → `DMChatView`).
    @Published var pendingDMConversationId: UUID?
}

struct ContentView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var authRepository = AuthRepository()
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var tabRouter = MainTabRouter()
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    @Environment(\.scenePhase) private var scenePhase

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
            deepLinkHandler.handle(url, tabRouter: tabRouter)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, authRepository.session != nil else { return }
            Task { await authRepository.refreshProfile() }
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
    @State private var showAppTutorial = false

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
        .animation(DeskerAnimation.tabCrossFade, value: tabRouter.selectedTab)
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
        .onChange(of: connectivity.isConnected) { _, online in
            if online {
                Task { await OfflineDirectMessageQueue.shared.flush(using: DMRepository()) }
            }
        }
        .overlay {
            if showAppTutorial {
                AppTutorialOverlay {
                    showAppTutorial = false
                }
                .transition(.opacity)
                .zIndex(50)
            }
        }
        .onAppear {
            TabBarAppearanceConfigurator.apply()
            PushNotificationService.shared.configure(tabRouter: tabRouter, auth: auth)
            Task { await refreshAllTabBadges() }
            if DeskerUXPreferences.pendingExploreAfterOnboarding {
                DeskerUXPreferences.pendingExploreAfterOnboarding = false
                withAnimation(DeskerAnimation.tabCrossFade) {
                    tabRouter.selectedTab = 0
                }
            }
            if DeskerUXPreferences.showAppTutorialAfterOnboarding, !DeskerUXPreferences.appTutorialDismissed {
                DeskerUXPreferences.showAppTutorialAfterOnboarding = false
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    showAppTutorial = true
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
            withAnimation(DeskerAnimation.tabCrossFade) {
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
    private var macOfflineBanner: some View {
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

    private var macTabContainer: some View {
        ZStack {
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
            .overlay(alignment: .top) {
                if !connectivity.isConnected {
                    macOfflineBanner
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: connectivity.isConnected)
            .onChange(of: connectivity.isConnected) { _, online in
                if online {
                    Task { await OfflineDirectMessageQueue.shared.flush(using: DMRepository()) }
                }
            }
        }
        .onAppear {
            PushNotificationService.shared.configure(tabRouter: tabRouter, auth: auth)
            Task { await MainTabBadgeCoordinator.refreshAppIconBadge(auth: auth) }
        }
    }
    #endif
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

enum MainTabBadgeCoordinator {
    @MainActor
    static func refreshAppIconBadge(auth: AuthRepository) async {
        guard let uid = auth.currentUser?.id else {
            #if os(iOS)
            UIApplication.shared.applicationIconBadgeNumber = 0
            #elseif os(macOS)
            NSApplication.shared.dockTile.badgeLabel = nil
            #endif
            return
        }
        let repo = NotificationRepository()
        let n = (try? await repo.unreadCount(userId: uid)) ?? 0
        let label = n > 0 ? (n > 99 ? "99+" : "\(n)") : nil
        #if os(iOS)
        UIApplication.shared.applicationIconBadgeNumber = min(99, n)
        #elseif os(macOS)
        NSApplication.shared.dockTile.badgeLabel = label
        #endif
    }
}
