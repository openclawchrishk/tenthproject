import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @State private var inviteInFlight = false

    private let connectionsRepo = ConnectionRepository()
    private let inviteRepo = InviteRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "探索",
                    subtitle: "發現新的創業 Desk 與機會"
                )

                searchAndFilters

                ScrollView {
                    VStack(spacing: CardChrome.sectionSpacing) {
                        if let err = viewModel.errorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 52))
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
                        } else if let desk = viewModel.currentDesk, let founder = viewModel.currentFounder {
                            VStack(spacing: 20) {
                                ExploreFounderCard(
                                    founder: founder,
                                    inviteCTAState: viewModel.inviteCTAState,
                                    inviteInFlight: inviteInFlight,
                                    onSendInvite: { Task { await sendDeskInvite() } }
                                )

                                DeskCardView(desk: desk, founder: founder) {
                                    HapticFeedback.medium()
                                    Task {
                                        await viewModel.viewAgain()
                                        await viewModel.refreshInviteCTAState(
                                            currentUserId: auth.currentUser?.id,
                                            inviteRepo: inviteRepo,
                                            connectionsRepo: connectionsRepo
                                        )
                                    }
                                }
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
                .refreshable { await reloadExploreAndInviteState() }
            }
            .background(AppColor.background.ignoresSafeArea())
            .overlay {
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(AppColor.secondary)
                        Text("載入中...")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: CardChrome.shadowColor, radius: 12, x: 0, y: 4)
                    )
                    .allowsHitTesting(false)
                }
            }
            .task {
                await reloadExploreAndInviteState()
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.applyFiltersReselectingIfNeeded()
            }
            .onChange(of: viewModel.selectedFilterChip) { _, _ in
                viewModel.applyFiltersReselectingIfNeeded()
            }
            .onChange(of: viewModel.currentFounder?.id) { _, _ in
                Task {
                    await viewModel.refreshInviteCTAState(
                        currentUserId: auth.currentUser?.id,
                        inviteRepo: inviteRepo,
                        connectionsRepo: connectionsRepo
                    )
                }
            }
            .onChange(of: auth.currentUser?.id) { _, _ in
                Task {
                    await viewModel.loadMyDesks(founderId: auth.currentUser?.id)
                    await viewModel.refreshInviteCTAState(
                        currentUserId: auth.currentUser?.id,
                        inviteRepo: inviteRepo,
                        connectionsRepo: connectionsRepo
                    )
                }
            }
            .deskerHiddenNavigationBar()
        }
    }

    private func reloadExploreAndInviteState() async {
        await viewModel.load()
        await viewModel.loadMyDesks(founderId: auth.currentUser?.id)
        await viewModel.refreshInviteCTAState(
            currentUserId: auth.currentUser?.id,
            inviteRepo: inviteRepo,
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
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(color: CardChrome.shadowColor.opacity(0.5), radius: 8, x: 0, y: 2)
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
                                .shadow(color: CardChrome.shadowColor.opacity(0.35), radius: 4, x: 0, y: 1)
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
        VStack(spacing: 16) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56))
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppColor.secondary, AppColor.gold.opacity(0.9))
            Text("暫時沒有其他創業者")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Text("稍後再回來看看")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func sendDeskInvite() async {
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
        guard let myDesk = viewModel.myDesks.first else {
            toast.show(.info, "請先建立 Desk")
            HapticFeedback.error()
            return
        }
        inviteInFlight = true
        defer { inviteInFlight = false }
        do {
            if try await connectionsRepo.areConnected(uid, founderId) {
                toast.show(.info, "你們已連接")
                HapticFeedback.success()
                await viewModel.refreshInviteCTAState(
                    currentUserId: auth.currentUser?.id,
                    inviteRepo: inviteRepo,
                    connectionsRepo: connectionsRepo
                )
                return
            }
            if let existing = try await inviteRepo.fetchInvite(deskId: myDesk.id, inviteeId: founderId),
               existing.status == .pending {
                toast.show(.info, "已發送過邀請")
                HapticFeedback.success()
                await viewModel.refreshInviteCTAState(
                    currentUserId: auth.currentUser?.id,
                    inviteRepo: inviteRepo,
                    connectionsRepo: connectionsRepo
                )
                return
            }
            try await inviteRepo.sendInvite(
                deskId: myDesk.id,
                inviterId: uid,
                inviteeId: founderId
            )
            toast.show(.success, "邀請已發送")
            HapticFeedback.success()
            await viewModel.refreshInviteCTAState(
                currentUserId: auth.currentUser?.id,
                inviteRepo: inviteRepo,
                connectionsRepo: connectionsRepo
            )
        } catch {
            toast.show(.error, error.localizedDescription)
            HapticFeedback.error()
        }
    }
}

// MARK: - Founder user card (Explore)

private struct ExploreFounderCard: View {
    let founder: UserProfile
    let inviteCTAState: ExploreInviteCTAState
    let inviteInFlight: Bool
    let onSendInvite: () -> Void

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

    private var displayName: String {
        let n = founder.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = n.isEmpty ? "創辦人" : n
        return base.deskerTruncated(maxLength: 20)
    }

    private var ctaTitle: String {
        switch inviteCTAState {
        case .loading: return "發送邀請"
        case .needsLogin: return "發送邀請"
        case .selfProfile: return "你的專案"
        case .noDesk: return "發送邀請"
        case .connected: return "已連接"
        case .pendingDeskInvite: return "已發送過邀請"
        case .pendingConnectionInvite: return "連接邀請待回覆"
        case .ready: return "發送邀請"
        }
    }

    private var ctaEnabled: Bool {
        switch inviteCTAState {
        case .ready, .noDesk, .needsLogin: return true
        default: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                founderAvatar
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(.headline)
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if founder.verificationBadgeStyle != nil {
                            Image(systemName: "star.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColor.gold)
                                .shadow(color: AppColor.gold.opacity(0.45), radius: 2, y: 0)
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
                            Text(skill)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColor.primary.opacity(0.1))
                                .foregroundStyle(AppColor.primary)
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

            Button(action: onSendInvite) {
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
                .cornerRadius(12)
            }
            .buttonStyle(DeskerCardPressStyle())
            .deskerButtonShadow()
            .disabled(inviteInFlight || !ctaEnabled || inviteCTAState == .loading || inviteCTAState == .selfProfile)
            .opacity(inviteCTAState == .selfProfile ? 0.55 : 1)

            if let foot = statusFootnote {
                Text(foot)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
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
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        } else if !detailed.isEmpty {
            Text(detailed.deskerTruncated(maxLength: 100))
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(3)
        } else {
            Text("未填寫")
                .font(.subheadline)
                .foregroundStyle(AppColor.textTertiary)
        }
    }

    private var statusFootnote: String? {
        switch inviteCTAState {
        case .connected: return "你們已連接"
        case .pendingDeskInvite: return "Desk 邀請待對方回覆"
        case .pendingConnectionInvite: return "連接邀請待對方回覆"
        case .noDesk: return "建立 Desk 後可邀請對方加入你的項目"
        case .needsLogin: return "登入後可發送邀請"
        default: return nil
        }
    }

    private var founderAvatar: some View {
        Group {
            if let s = founder.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        initialsAvatar
                    case .empty:
                        ProgressView()
                            .tint(AppColor.secondary)
                    @unknown default:
                        initialsAvatar
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
            } else {
                initialsAvatar
            }
        }
    }

    private var initialsAvatar: some View {
        let initials = initialsFromName(displayName)
        return ZStack {
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                .fill(AppColor.primary)
                .frame(width: 72, height: 72)
            Text(initials)
                .font(.title2.weight(.bold))
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
}
