import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var tabRouter: MainTabRouter
    @State private var inviteInFlightUserId: UUID?
    @State private var isPullRefreshing = false
    @State private var profileSheetUser: UserProfile?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var searchDebounceTask: Task<Void, Never>?
    /// Shuffled copy of `filteredDesks` for the Tinder-style deck.
    @State private var exploreDeskDeck: [Desk] = []
    @State private var exploreDeskListMode = false

    private let connectionsRepo = ConnectionRepository()
    private let usersRepo = UserRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "探索",
                    subtitle: "發現新的創業 Desk 與機會"
                )

                searchAndFilters

                browseTabPicker

                ZStack(alignment: .top) {
                    ScrollView {
                        LazyVStack(spacing: CardChrome.sectionSpacing) {
                            if viewModel.browseTab == .desks {
                                deskBrowseSection
                            } else {
                                usersBrowseSection
                            }
                        }
                        .padding(.bottom, CardChrome.sectionSpacing)
                    }
                    .refreshable {
                        #if os(iOS)
                        HapticFeedback.light()
                        #endif
                        isPullRefreshing = true
                        await reloadExploreAndInviteState()
                        withAnimation(.easeInOut(duration: 0.28)) {
                            isPullRefreshing = false
                        }
                    }
                    #if os(iOS)
                    .scrollDismissesKeyboard(.interactively)
                    #endif

                    if isPullRefreshing {
                        DeskerCustomRefreshIndicator()
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
            }
            .background(AppColor.background.ignoresSafeArea())
            .overlay {
                if viewModel.isFilterBusy {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(AppColor.gold)
                    }
                }
            }
            .task {
                await reloadExploreAndInviteState()
                reshuffleExploreDeskDeck()
            }
            .onChange(of: viewModel.searchText) { _, _ in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        viewModel.applyFiltersReselectingIfNeeded()
                        reshuffleExploreDeskDeck()
                    }
                }
            }
            .onChange(of: viewModel.selectedFilterChip) { _, _ in
                viewModel.applyFiltersReselectingIfNeeded()
                reshuffleExploreDeskDeck()
            }
            .onChange(of: viewModel.errorMessage) { _, new in
                if let new, !viewModel.desks.isEmpty, !viewModel.filteredDesks.isEmpty {
                    toast.show(.info, "無法更新列表：\(new)")
                }
            }
            .onDisappear {
                searchDebounceTask?.cancel()
                searchDebounceTask = nil
            }
            .onChange(of: auth.currentUser?.id) { _, _ in
                Task {
                    await viewModel.loadMyDesks(founderId: auth.currentUser?.id)
                    await viewModel.refreshInviteCTAState(
                        currentUserId: auth.currentUser?.id,
                        connectionsRepo: connectionsRepo
                    )
                }
            }
            .onChange(of: viewModel.browseTab) { _, tab in
                viewModel.resetListPagination()
                if tab == .users, viewModel.browseUsers.isEmpty {
                    Task { await viewModel.loadBrowseUsers() }
                }
            }
            .onChange(of: tabRouter.pendingExploreProfileUserId) { _, uid in
                guard let uid else { return }
                Task {
                    if let p = try? await usersRepo.fetchUser(id: uid) {
                        await MainActor.run { profileSheetUser = p }
                    }
                    await MainActor.run { tabRouter.pendingExploreProfileUserId = nil }
                }
            }
            .onChange(of: tabRouter.pendingExploreUsername) { _, name in
                guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task {
                    if let p = try? await usersRepo.fetchUserByUsername(name) {
                        await MainActor.run { profileSheetUser = p }
                    }
                    await MainActor.run { tabRouter.pendingExploreUsername = nil }
                }
            }
            .deskerHiddenNavigationBar()
            #if os(iOS)
            .sheet(isPresented: $showShareSheet, onDismiss: {}) {
                ShareSheetView(items: shareItems)
            }
            #endif
            .sheet(item: $profileSheetUser, onDismiss: {}) { user in
                ExplorePublicProfileSheet(
                    founder: user,
                    desk: nil
                )
            }
            .navigationDestination(for: UUID.self) { deskId in
                DeskDetailView(deskId: deskId)
            }
        }
    }

    private func reshuffleExploreDeskDeck() {
        exploreDeskDeck = viewModel.filteredDesks.shuffled()
    }

    private var browseTabPicker: some View {
        Picker("瀏覽", selection: $viewModel.browseTab) {
            ForEach(ExploreBrowseTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, CardChrome.padding)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var deskBrowseSection: some View {
        if let err = viewModel.errorMessage, viewModel.desks.isEmpty {
            DeskerErrorStateView(message: err, onRetry: {
                HapticFeedback.medium()
                Task { await reloadExploreAndInviteState() }
            }, detail: nil)
        } else if viewModel.isLoading, viewModel.desks.isEmpty {
            VStack(spacing: 20) {
                ExploreCardSkeleton()
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .frame(height: 140)
                    .deskerSkeletonShimmer(active: true)
                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
            }
            .padding(.horizontal, CardChrome.padding)
        } else if viewModel.filteredDesks.isEmpty {
            exploreEmpty
                .padding(.horizontal, CardChrome.padding)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Desk 顯示方式", selection: $exploreDeskListMode) {
                    Text("卡片滑卡").tag(false)
                    Text("列表").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, CardChrome.padding)

                if exploreDeskListMode {
                    ForEach(viewModel.pagedFilteredDesks) { desk in
                        NavigationLink(value: desk.id) {
                            ExploreDeskBrowseCard(desk: desk)
                        }
                        .buttonStyle(DeskerCardPressStyle())
                    }
                    .padding(.horizontal, CardChrome.padding)
                    if viewModel.canLoadMoreDesks {
                        Button {
                            HapticFeedback.light()
                            viewModel.loadMoreDesks()
                        } label: {
                            Text("載入更多")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColor.surfaceElevated)
                                .foregroundStyle(AppColor.primary)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, CardChrome.padding)
                    }
                } else {
                    ExploreDeskSwipeDeckView(
                        stack: $exploreDeskDeck,
                        founderNames: viewModel.founderDisplayNameByFounderId,
                        onNeedMoreCards: { reshuffleExploreDeskDeck() }
                    )
                    .padding(.horizontal, CardChrome.padding)
                }
            }
        }
    }

    @ViewBuilder
    private var usersBrowseSection: some View {
        let users = viewModel.pagedBrowseUsers(exceptUserId: auth.currentUser?.id)
        let allFiltered = viewModel.filteredBrowseUsers(exceptUserId: auth.currentUser?.id)
        VStack(alignment: .leading, spacing: 12) {
            if let uErr = viewModel.browseUsersError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColor.warning)
                    Text(uErr)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                        .fill(AppColor.warning.opacity(0.12))
                )
            }
            if allFiltered.isEmpty {
                Group {
                    if viewModel.browseUsers.isEmpty {
                        exploreUsersEmpty
                    } else {
                        exploreUsersFilteredEmpty
                    }
                }
            } else {
                ForEach(users) { user in
                    ExploreUserBrowseCard(
                        user: user,
                        connectBusy: inviteInFlightUserId == user.id,
                        onProfile: {
                            profileSheetUser = user
                            HapticFeedback.light()
                        },
                        onConnect: {
                            Task { await connectFromDirectory(user) }
                        }
                    )
                }
                if viewModel.canLoadMoreUsers(exceptUserId: auth.currentUser?.id) {
                    Button {
                        HapticFeedback.light()
                        viewModel.loadMoreUsers()
                    } label: {
                        Text("載入更多")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColor.surfaceElevated)
                            .foregroundStyle(AppColor.primary)
                            .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, CardChrome.padding)
    }

    private func connectFromDirectory(_ user: UserProfile) async {
        HapticFeedback.medium()
        guard let uid = auth.currentUser?.id else {
            toast.show(.error, "請先登入")
            return
        }
        if user.id == uid {
            toast.show(.info, "呢個係你本人")
            return
        }
        inviteInFlightUserId = user.id
        defer { inviteInFlightUserId = nil }
        do {
            if try await connectionsRepo.areConnected(uid, user.id) {
                toast.show(.info, "你們已連接")
                HapticFeedback.success()
                return
            }
            if try await connectionsRepo.outgoingPendingConnectionInvite(from: uid, to: user.id) != nil {
                toast.show(.info, "連接邀請待對方回覆")
                HapticFeedback.success()
                return
            }
            try await connectionsRepo.sendConnectionInvite(from: uid, to: user.id, message: nil)
            toast.show(.success, "連接邀請已送出")
            HapticFeedback.success()
        } catch {
            toast.show(.error, APIErrorMessages.userFacingMessage(for: error))
            HapticFeedback.error()
        }
    }

    private var exploreUsersEmpty: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.secondary)
            Text("暫時沒有創業者")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text("成為第一個創業者")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                HapticFeedback.medium()
                withAnimation(DeskerAnimation.tabCrossFade) {
                    tabRouter.selectedTab = 3
                }
            } label: {
                Text("前往「我的」完善資料")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppColor.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(DeskerButtonPressStyle())
            .padding(.horizontal, CardChrome.padding)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var exploreUsersFilteredEmpty: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.3")
                .font(.system(size: 44))
                .foregroundStyle(AppColor.secondary)
            Text("沒有符合的用戶")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text("試試其他關鍵字或篩選條件。")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func reloadExploreAndInviteState() async {
        await viewModel.load()
        await viewModel.loadBrowseUsers()
        await viewModel.loadMyDesks(founderId: auth.currentUser?.id)
        await viewModel.refreshInviteCTAState(
            currentUserId: auth.currentUser?.id,
            connectionsRepo: connectionsRepo
        )
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.gold.opacity(0.9))
                TextField("搜尋創業者或Desk", text: $viewModel.searchText)
                    .font(.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .deskerTextFieldNoAutocaps()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                            .fill(AppColor.cardBackground.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.65), AppColor.gold.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
            )
            .padding(.horizontal, CardChrome.padding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExploreViewModel.filterChipOptions, id: \.self) { chip in
                        let on = viewModel.selectedFilterChip == chip
                        Button {
                            HapticFeedback.selection()
                            viewModel.selectedFilterChip = chip
                        } label: {
                            Text(chip)
                                .font(.subheadline.weight(on ? .semibold : .regular))
                                .tracking(-0.1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                                        .fill(on ? AppColor.primary : AppColor.primary.opacity(0.1))
                                )
                                .foregroundStyle(on ? Color.white : AppColor.primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                                        .stroke(on ? AppColor.gold.opacity(0.45) : Color.clear, lineWidth: 1)
                                )
                                .shadow(color: on ? AppColor.gold.opacity(0.22) : Color.clear, radius: 8, x: 0, y: 2)
                                .scaleEffect(on ? 1.04 : 1)
                                .animation(.spring(response: 0.32, dampingFraction: 0.72), value: on)
                        }
                        .buttonStyle(DeskerChipPressStyle())
                    }
                }
                .padding(.horizontal, CardChrome.padding)
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 8)
    }

    private var exploreEmpty: some View {
        let noDesksAtAll = viewModel.desks.isEmpty
        return VStack(spacing: 18) {
            Image(systemName: noDesksAtAll ? "person.3.sequence" : "briefcase")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.secondary)
                .symbolRenderingMode(.hierarchical)
            Text(noDesksAtAll ? "暫時沒有創業者" : "暫時沒有Desk")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(noDesksAtAll ? "成為第一個創業者" : "調整上方篩選或搜尋，或稍後再試。")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 520)
            Group {
                if noDesksAtAll {
                    Button {
                        HapticFeedback.medium()
                        withAnimation(DeskerAnimation.tabCrossFade) {
                            tabRouter.selectedTab = 3
                        }
                    } label: {
                        Text("前往「我的」完善資料")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.brandGradient)
                            .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                    }
                    .buttonStyle(DeskerButtonPressStyle())
                } else {
                    Button {
                        HapticFeedback.medium()
                        viewModel.selectedFilterChip = "全部"
                        viewModel.searchText = ""
                        viewModel.applyFiltersReselectingIfNeeded()
                    } label: {
                        Text("重設篩選")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.brandGradient)
                            .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                    }
                    .buttonStyle(DeskerButtonPressStyle())
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

// MARK: - Custom refresh + public profile preview

private struct DeskerCustomRefreshIndicator: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(AppColor.primary)
                .scaleEffect(1.05)
            Text("更新中…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .deskerFloatingShadow()
    }
}

private struct ExplorePublicProfileSheet: View {
    let founder: UserProfile
    let desk: Desk?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 16) {
                        founderAvatar
                        VStack(alignment: .leading, spacing: 6) {
                            Text(founder.displayName.isEmpty ? "創業者" : founder.displayName)
                                .font(.title2.bold())
                                .foregroundStyle(AppColor.textPrimary)
                                .lineLimit(2)
                            Text(founder.role.localizedName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RoleBadgePalette.color(for: founder.role))
                        }
                    }
                    if let bio = founder.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .lineSpacing(4)
                            .frame(maxWidth: 560, alignment: .leading)
                    }
                    if let desk {
                        NavigationLink {
                            DeskDetailView(deskId: desk.id)
                        } label: {
                            Label("查看 Desk：\(desk.name)", systemImage: "briefcase.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColor.brandGradient)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CardChrome.padding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("創業者")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .deskerSheetSpringContent()
    }

    private var founderAvatar: some View {
        Group {
            if let s = founder.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                CachedAsyncImage(url: url, maxPixelDimension: 240) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                            .tint(AppColor.primary)
                    case .failure:
                        placeholder
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
            .fill(AppColor.primary)
            .frame(width: 72, height: 72)
            .overlay {
                Text(String(founder.displayName.prefix(1)).uppercased())
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Desk swipe deck (Tinder-style)

private struct ExploreDeskSwipeDeckView: View {
    @Binding var stack: [Desk]
    let founderNames: [UUID: String]
    let onNeedMoreCards: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0

    var body: some View {
        if stack.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "rectangle.stack.fill.badge.person.crop")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColor.secondary)
                    .symbolRenderingMode(.hierarchical)
                Text("這批 Desk 已看完")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text("向左或向右滑可略過；或重新洗牌繼續探索。")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    HapticFeedback.medium()
                    onNeedMoreCards()
                } label: {
                    Text("重新洗牌")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(DeskerButtonPressStyle())
            }
            .padding(.vertical, 28)
        } else {
            VStack(spacing: 16) {
                ZStack {
                    ForEach(Array(stack.prefix(3).enumerated()), id: \.element.id) { index, desk in
                        swipeCard(desk: desk, isTop: index == 0, depth: index)
                    }
                }
                .frame(height: 400)

                if let top = stack.first {
                    HStack(spacing: 12) {
                        Button {
                            skipTop()
                        } label: {
                            Label("略過", systemImage: "xmark")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColor.surfaceElevated)
                                .foregroundStyle(AppColor.error)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: top.id) {
                            Label("查看 Desk", systemImage: "arrow.right.circle.fill")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColor.brandGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("左右滑動略過 · 底部可開詳情")
                    .font(.caption)
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
    }

    private func founderLine(for desk: Desk) -> String {
        let n = founderNames[desk.founderId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? "創辦人" : n
    }

    private func swipeCard(desk: Desk, isTop: Bool, depth: Int) -> some View {
        let lift = CGFloat(depth) * 10
        let scale = 1.0 - Double(depth) * 0.045
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(desk.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)
                Spacer()
                deskStatusPill(desk.status)
            }
            Text(founderLine(for: desk))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.gold)
            Text(desk.pitch)
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(5)
                .lineSpacing(3)
            if !desk.industryTags.isEmpty {
                Text(desk.industryTags.joined(separator: " · "))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColor.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack {
                Label("\(desk.currentMemberCount) / \(desk.memberLimit) 人", systemImage: "person.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
                Spacer()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColor.cardBackground.opacity(0.95),
                                    AppColor.primary.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), AppColor.gold.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
        }
        .offset(y: lift)
        .scaleEffect(scale)
        .offset(x: isTop ? dragOffset.width : 0, y: isTop ? dragOffset.height * 0.15 : 0)
        .rotationEffect(.degrees(isTop ? dragRotation : 0))
        .zIndex(Double(100 - depth))
        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.78), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { v in
                    guard isTop else { return }
                    dragOffset = v.translation
                    dragRotation = Double(v.translation.width / 18)
                }
                .onEnded { v in
                    guard isTop else { return }
                    if abs(v.translation.width) > 90 || abs(v.predictedEndTranslation.width) > 200 {
                        skipTop()
                    }
                    dragOffset = .zero
                    dragRotation = 0
                }
        )
    }

    private func deskStatusPill(_ status: DeskStatus) -> some View {
        let (t, c): (String, Color) = {
            switch status {
            case .recruiting: return ("招募中", AppColor.secondary)
            case .full: return ("已滿", AppColor.warning)
            case .archived: return ("已歸檔", AppColor.textSecondary)
            }
        }()
        return Text(t)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(c.opacity(0.2))
            .foregroundStyle(c)
            .clipShape(Capsule())
    }

    private func skipTop() {
        guard !stack.isEmpty else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            stack.removeFirst()
        }
        HapticFeedback.light()
        if stack.isEmpty {
            onNeedMoreCards()
        }
    }
}

// MARK: - Browse cards (Users / Desks)

private struct ExploreDeskBrowseCard: View {
    let desk: Desk

    private var industryLine: String {
        desk.industryTags.isEmpty ? "—" : desk.industryTags.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(desk.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
            Text(desk.pitch)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(industryLine)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.secondary)
                .lineLimit(2)
            HStack {
                Label("\(desk.currentMemberCount) / \(desk.memberLimit) 人", systemImage: "person.2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
                Spacer()
                exploreDeskStatusCapsule(desk.status)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }

    @ViewBuilder
    private func exploreDeskStatusCapsule(_ status: DeskStatus) -> some View {
        let (t, c): (String, Color) = {
            switch status {
            case .recruiting: return ("招募中", AppColor.secondary)
            case .full: return ("已滿", AppColor.warning)
            case .archived: return ("已歸檔", AppColor.textSecondary)
            }
        }()
        Text(t)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(c.opacity(0.2))
            .foregroundStyle(c)
            .clipShape(Capsule())
    }
}

private struct ExploreUserBrowseCard: View {
    let user: UserProfile
    let connectBusy: Bool
    let onProfile: () -> Void
    let onConnect: () -> Void

    private var bioLine: String {
        let b = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !b.isEmpty { return b.deskerTruncated(maxLength: 120) }
        let d = user.detailedBio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return d.isEmpty ? "—" : d.deskerTruncated(maxLength: 120)
    }

    private var skillChips: [String] {
        Array(user.skills.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 6) {
                    Text(user.displayName.isEmpty ? "用戶" : user.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                    Text(user.role.localizedName)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoleBadgePalette.color(for: user.role).opacity(0.18))
                        .foregroundStyle(RoleBadgePalette.color(for: user.role))
                        .clipShape(Capsule())
                    Text(bioLine)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if !skillChips.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), alignment: .leading)], alignment: .leading, spacing: 6) {
                    ForEach(skillChips, id: \.self) { s in
                        Text(s)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColor.primary.opacity(0.1))
                            .foregroundStyle(AppColor.primary)
                            .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                    }
                }
            }
            HStack(spacing: 10) {
                Button(action: onProfile) {
                    Text("查看")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColor.surfaceElevated)
                        .foregroundStyle(AppColor.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(.plain)
                Button(action: onConnect) {
                    Group {
                        if connectBusy {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            Text("連接")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .background(AppColor.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(connectBusy)
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }

    @ViewBuilder
    private var avatar: some View {
        if let s = user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           let url = URL(string: s) {
            CachedAsyncImage(url: url, maxPixelDimension: 200) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    ProgressView().tint(AppColor.primary)
                case .failure:
                    placeholder
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        let n = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = n.first.map(String.init) ?? "?"
        return ZStack {
            Circle()
                .fill(AppColor.brandGradient)
                .frame(width: 56, height: 56)
            Text(initial)
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
    }
}
