import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Namespace private var exploreCardNamespace
    @State private var inviteInFlight = false
    @State private var showConnectionMessageSheet = false
    @State private var connectionMessageDraft = ""
    @State private var isPullRefreshing = false
    @State private var profileSheetUser: UserProfile?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var cardDragTranslation: CGFloat = 0
    @State private var showExploreSwipeTipBanner = false
    @State private var searchDebounceTask: Task<Void, Never>?

    private let connectionsRepo = ConnectionRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "探索",
                    subtitle: "發現新的創業 Desk 與機會"
                )

                searchAndFilters

                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(spacing: CardChrome.sectionSpacing) {
                            if let err = viewModel.errorMessage,
                               viewModel.currentDesk == nil || viewModel.currentFounder == nil {
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(AppColor.error)
                                    Text(err)
                                        .font(.subheadline)
                                        .foregroundStyle(AppColor.error)
                                        .multilineTextAlignment(.center)
                                    Button("重試") {
                                        HapticFeedback.medium()
                                        Task { await reloadExploreAndInviteState() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppColor.primary)
                                }
                                .padding(CardChrome.padding)
                            } else if viewModel.isLoading, viewModel.currentDesk == nil {
                                VStack(spacing: 20) {
                                    ExploreCardSkeleton()
                                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                                        .fill(AppColor.cardBackground)
                                        .frame(height: 140)
                                        .deskerPulse(active: true)
                                        .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                                }
                                .padding(.horizontal, CardChrome.padding)
                            } else if let desk = viewModel.currentDesk, let founder = viewModel.currentFounder {
                                VStack(spacing: 20) {
                                    founderCardWithGestures(desk: desk, founder: founder)

                                    DeskCardView(desk: desk, founder: founder) {
                                        HapticFeedback.medium()
                                        Task {
                                            await viewModel.viewAgain()
                                            await viewModel.refreshInviteCTAState(
                                                currentUserId: auth.currentUser?.id,
                                                connectionsRepo: connectionsRepo
                                            )
                                        }
                                    }
                                    .matchedGeometryEffect(id: "desk-\(desk.id)", in: exploreCardNamespace)
                                    .id("\(viewModel.refreshGeneration.uuidString)-\(desk.id.uuidString)")

                                    NavigationLink {
                                        DeskDetailView(deskId: desk.id)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(AppColor.primary, AppColor.secondary)
                                            Text("查看完整專案詳情")
                                                .font(.headline)
                                                .foregroundStyle(AppColor.primary)
                                                .lineLimit(1)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(AppColor.textSecondary)
                                        }
                                        .padding(CardChrome.padding)
                                        .deskerElevatedCard()
                                    }
                                    .buttonStyle(DeskerCardPressStyle())
                                }
                                .padding(.horizontal, CardChrome.padding)
                            } else {
                                exploreEmpty
                                    .padding(.horizontal, CardChrome.padding)
                            }
                        }
                        .padding(.bottom, CardChrome.sectionSpacing)
                    }
                    .refreshable {
                        isPullRefreshing = true
                        await reloadExploreAndInviteState()
                        withAnimation(.easeInOut(duration: 0.28)) {
                            isPullRefreshing = false
                        }
                    }

                    if isPullRefreshing {
                        DeskerCustomRefreshIndicator()
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
            }
            .background(AppColor.background.ignoresSafeArea())
            .overlay(alignment: .top) {
                if showExploreSwipeTipBanner {
                    exploreSwipeTipBanner
                        .padding(.horizontal, CardChrome.padding)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                await reloadExploreAndInviteState()
            }
            .onChange(of: viewModel.searchText) { _, _ in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        viewModel.applyFiltersReselectingIfNeeded()
                    }
                }
            }
            .onChange(of: viewModel.selectedFilterChip) { _, _ in
                viewModel.applyFiltersReselectingIfNeeded()
            }
            .onChange(of: viewModel.errorMessage) { _, new in
                if let new, !viewModel.desks.isEmpty, viewModel.currentDesk != nil, viewModel.currentFounder != nil {
                    toast.show(.info, "無法更新列表：\(new)")
                }
            }
            .onDisappear {
                searchDebounceTask?.cancel()
                searchDebounceTask = nil
            }
            .onChange(of: viewModel.currentFounder?.id) { _, _ in
                Task {
                    await viewModel.refreshInviteCTAState(
                        currentUserId: auth.currentUser?.id,
                        connectionsRepo: connectionsRepo
                    )
                }
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
            .deskerHiddenNavigationBar()
            .sheet(isPresented: $showConnectionMessageSheet) {
                connectionInviteMessageSheet
            }
            #if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                ShareSheetView(items: shareItems)
            }
            #endif
            .sheet(item: $profileSheetUser) { founder in
                ExplorePublicProfileSheet(
                    founder: founder,
                    desk: viewModel.currentDesk
                )
            }
            .onAppear {
                showExploreSwipeTipBanner = DeskerUXPreferences.showExploreSwipeTip && !DeskerUXPreferences.tipExploreDismissed
            }
        }
    }

    private func founderCardWithGestures(desk: Desk, founder: UserProfile) -> some View {
        ZStack {
            HStack(spacing: 0) {
                swipeHintChip(title: "快速連接", icon: "bolt.horizontal.fill", color: AppColor.primary)
                Spacer()
                swipeHintChip(title: "收藏", icon: "star.fill", color: AppColor.gold)
            }
            .padding(.horizontal, 8)
            .opacity(min(1, abs(cardDragTranslation) / 72))

            ExploreFounderCard(
                founder: founder,
                inviteCTAState: viewModel.inviteCTAState,
                inviteInFlight: inviteInFlight,
                onConnect: { showConnectionMessageSheet = true }
            )
            .matchedGeometryEffect(id: "founder-\(founder.id)", in: exploreCardNamespace)
            .offset(x: cardDragTranslation)
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: cardDragTranslation)
            .highPriorityGesture(
                DragGesture(minimumDistance: 28, coordinateSpace: .local)
                    .onChanged { value in
                        let w = value.translation.width
                        let h = value.translation.height
                        guard abs(w) > abs(h) else { return }
                        cardDragTranslation = max(-130, min(130, w))
                    }
                    .onEnded { value in
                        let w = value.translation.width
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            if w < -88 {
                                Task { await quickConnectInvite() }
                            } else if w > 88 {
                                DeskerUXPreferences.toggleFavoriteFounder(founder.id)
                                HapticFeedback.success()
                                let on = DeskerUXPreferences.isFavoriteFounder(founder.id)
                                toast.show(.success, on ? "已加入收藏（稍後可用）" : "已取消收藏")
                            }
                            cardDragTranslation = 0
                        }
                    }
            )
            .onTapGesture(count: 2) {
                profileSheetUser = founder
                HapticFeedback.light()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                #if os(iOS)
                shareItems = [PublicLinks.profilePublicURL(for: founder)]
                showShareSheet = true
                HapticFeedback.medium()
                #endif
            }
        }
    }

    private func swipeHintChip(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(color.opacity(0.92)))
    }

    private func quickConnectInvite() async {
        await sendConnectionInviteWithOptionalMessage(nil)
    }

    private var exploreSwipeTipBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.title2)
                .foregroundStyle(AppColor.primary)
            VStack(alignment: .leading, spacing: 6) {
                Text("探索小貼士")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("向左滑睇更多創業者，向右滑睇Desk")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    DeskerUXPreferences.showExploreSwipeTip = false
                    DeskerUXPreferences.tipExploreDismissed = true
                    showExploreSwipeTipBanner = false
                }
                HapticFeedback.selection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.textTertiary, AppColor.secondaryGroupedSurface)
            }
            .buttonStyle(.plain)
        }
        .padding(CardChrome.padding)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .stroke(AppColor.primary.opacity(0.2), lineWidth: 1)
        )
    }

    private func reloadExploreAndInviteState() async {
        await viewModel.load()
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
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                TextField("搜尋專案名稱或 Pitch", text: $viewModel.searchText)
                    .font(.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .deskerTextFieldNoAutocaps()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: CardChrome.buttonShadowColor, radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
            )
            .padding(.horizontal, CardChrome.padding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExploreViewModel.filterChipOptions, id: \.self) { chip in
                        let on = viewModel.selectedFilterChip == chip
                        Button {
                            HapticFeedback.selection()
                            viewModel.selectedFilterChip = chip
                            viewModel.applyFiltersReselectingIfNeeded()
                        } label: {
                            Text(chip)
                                .font(.subheadline.weight(on ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                                        .fill(on ? AppColor.primary : AppColor.primary.opacity(0.1))
                                )
                                .foregroundStyle(on ? Color.white : AppColor.primary)
                                .shadow(color: on ? CardChrome.buttonShadowColor : Color.clear, radius: 4, x: 0, y: 1)
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
        VStack(spacing: 18) {
            Image(systemName: "person.3.sequence")
                .font(.system(size: 52))
                .foregroundStyle(AppColor.secondary)
                .symbolRenderingMode(.hierarchical)
            Text("暫時沒有創業者，稍後再回來")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("先完善個人資料，讓社群更了解你；或調整篩選稍後再試。")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 520)
            Button {
                HapticFeedback.medium()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
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
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private var connectionInviteMessageSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("可選：一句話介紹自己或說明為何想連接（最多 150 字）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("個人訊息（可選）", text: $connectionMessageDraft, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: connectionMessageDraft) { _, new in
                            if new.count > 150 {
                                connectionMessageDraft = String(new.prefix(150))
                            }
                        }
                    Text("\(connectionMessageDraft.count)/150")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .navigationTitle("發送連接邀請")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showConnectionMessageSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送出") {
                        Task { await submitConnectionInvite() }
                    }
                    .disabled(inviteInFlight)
                }
            }
        }
    }

    private func submitConnectionInvite() async {
        let msg = connectionMessageDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        await sendConnectionInviteWithOptionalMessage(msg.isEmpty ? nil : msg)
    }

    private func sendConnectionInviteWithOptionalMessage(_ message: String?) async {
        HapticFeedback.medium()
        guard let uid = auth.currentUser?.id else {
            toast.show(.error, "請先登入")
            HapticFeedback.error()
            return
        }
        guard let founder = viewModel.currentFounder else { return }
        let founderId = founder.id
        if founderId == uid {
            toast.show(.info, "這是你本人")
            return
        }
        inviteInFlight = true
        defer { inviteInFlight = false }
        do {
            if try await connectionsRepo.areConnected(uid, founderId) {
                toast.show(.info, "你們已連接")
                showConnectionMessageSheet = false
                HapticFeedback.success()
                await viewModel.refreshInviteCTAState(
                    currentUserId: auth.currentUser?.id,
                    connectionsRepo: connectionsRepo
                )
                return
            }
            if try await connectionsRepo.outgoingPendingConnectionInvite(from: uid, to: founderId) != nil {
                toast.show(.info, "連接邀請待對方回覆")
                showConnectionMessageSheet = false
                HapticFeedback.success()
                await viewModel.refreshInviteCTAState(
                    currentUserId: auth.currentUser?.id,
                    connectionsRepo: connectionsRepo
                )
                return
            }
            let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
            try await connectionsRepo.sendConnectionInvite(
                from: uid,
                to: founderId,
                message: (trimmed?.isEmpty ?? true) ? nil : trimmed
            )
            connectionMessageDraft = ""
            showConnectionMessageSheet = false
            toast.show(.success, "連接邀請已送出")
            HapticFeedback.success()
            await viewModel.refreshInviteCTAState(
                currentUserId: auth.currentUser?.id,
                connectionsRepo: connectionsRepo
            )
        } catch {
            let desc = error.localizedDescription
            if desc.localizedCaseInsensitiveContains("duplicate") || desc.contains("23505") {
                toast.show(.info, "已發送過邀請")
            } else {
                toast.show(.error, desc)
            }
            HapticFeedback.error()
        }
    }
}

// MARK: - Custom refresh + public profile preview

private struct DeskerCustomRefreshIndicator: View {
    @State private var spin = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColor.primary)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
                .onAppear { spin = true }
            Text("更新中…")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: CardChrome.shadowColor, radius: 8, x: 0, y: 3)
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
                    Button("關閉") { dismiss() }
                }
            }
        }
        .deskerSheetSpringContent()
    }

    private var founderAvatar: some View {
        Group {
            if let s = founder.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                CachedAsyncImage(url: url) { phase in
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

// MARK: - Founder user card (Explore)

private struct ExploreFounderCard: View {
    let founder: UserProfile
    let inviteCTAState: ExploreInviteCTAState
    let inviteInFlight: Bool
    let onConnect: () -> Void

    private var skillChips: [String] {
        let s = Array(founder.skills.prefix(3))
        if s.isEmpty { return Array(founder.industryTags.prefix(3)) }
        return s
    }

    private var skillChipExtraCount: Int {
        if !founder.skills.isEmpty {
            return max(0, founder.skills.count - 3)
        }
        return max(0, founder.industryTags.count - 3)
    }

    private var showOnlineDot: Bool {
        !founder.skills.isEmpty || !founder.industryTags.isEmpty
    }

    private var displayName: String {
        let n = founder.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = n.isEmpty ? "創辦人" : n
        return base.deskerTruncated(maxLength: 20)
    }

    private var ctaTitle: String {
        switch inviteCTAState {
        case .loading: return "連接"
        case .needsLogin: return "連接"
        case .selfProfile: return "你的專案"
        case .connected: return "已連接"
        case .pendingConnectionInvite: return "連接邀請待回覆"
        case .ready: return "連接"
        case .error(_): return "重試連接"
        }
    }

    private var ctaEnabled: Bool {
        switch inviteCTAState {
        case .ready, .needsLogin, .error(_): return true
        default: return false
        }
    }

    private var inviteCTAStateIsError: Bool {
        if case .error = inviteCTAState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                founderAvatar
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let v = founder.verificationBadgeStyle {
                            VerificationBadgeView(style: v)
                        }
                    }
                    roleBadge
                    bioBlock
                }
            }

            if !skillChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(skillChips, id: \.self) { skill in
                            let c = skillChipColor(skill)
                            Text(skill)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(c.opacity(0.14))
                                .foregroundStyle(c)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                        }
                        if skillChipExtraCount > 0 {
                            Text("+\(skillChipExtraCount) 更多")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppColor.gold.opacity(0.15))
                                .foregroundStyle(AppColor.primary)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                        }
                    }
                }
            }

            Button(action: onConnect) {
                HStack {
                    if inviteInFlight {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [AppColor.primary, AppColor.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(DeskerButtonPressStyle())
            .deskerButtonShadow()
            .disabled(inviteInFlight || !ctaEnabled || inviteCTAState == .loading || inviteCTAState == .selfProfile)
            .opacity(inviteCTAState == .selfProfile ? 0.55 : 1)

            if let foot = statusFootnote {
                Text(foot)
                    .font(.footnote)
                    .foregroundStyle(inviteCTAStateIsError ? AppColor.error : AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }

    @ViewBuilder
    private var bioBlock: some View {
        let bio = founder.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let detailed = founder.detailedBio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !bio.isEmpty {
            Text(bio.deskerTruncated(maxLength: 100))
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } else if !detailed.isEmpty {
            Text(detailed.deskerTruncated(maxLength: 100))
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(2)
        } else {
            Text("未填寫")
                .font(.subheadline)
                .foregroundStyle(AppColor.textTertiary)
        }
    }

    private var statusFootnote: String? {
        switch inviteCTAState {
        case .connected: return "你們已連接，可於「訊息」→「人脈」開啟私訊"
        case .pendingConnectionInvite: return "連接邀請待對方回覆"
        case .needsLogin: return "登入後可發送連接邀請"
        case .error(let message): return message
        default: return nil
        }
    }

    private var founderAvatar: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let s = founder.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
                   let url = URL(string: s) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            initialsAvatar
                        case .empty:
                            ProgressView()
                                .tint(AppColor.primary)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                } else {
                    initialsAvatar
                }
            }
            if showOnlineDot {
                Circle()
                    .fill(AppColor.success)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 4, y: -2)
            }
        }
    }

    private var initialsAvatar: some View {
        let initials = initialsFromName(displayName)
        return ZStack {
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                .fill(AppColor.primary)
                .frame(width: 60, height: 60)
            Text(initials)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func initialsFromName(_ name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        let s = String(name.prefix(2))
        return s.isEmpty ? "?" : s.uppercased()
    }

    private var roleBadge: some View {
        Text(founder.role.localizedName)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoleBadgePalette.color(for: founder.role).opacity(0.18))
            .foregroundStyle(RoleBadgePalette.color(for: founder.role))
            .clipShape(Capsule())
    }

    private func skillChipColor(_ skill: String) -> Color {
        let palette: [Color] = [AppColor.primary, AppColor.secondary, AppColor.teal, AppColor.gold]
        let i = abs(skill.hashValue) % palette.count
        return palette[i]
    }
}
