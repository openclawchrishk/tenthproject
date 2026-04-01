import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @EnvironmentObject private var auth: AuthRepository
    @State private var connectBanner: String?
    @State private var connectInFlight = false

    private let connectionsRepo = ConnectionRepository()

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
                        if viewModel.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(AppColor.primary)
                                Text("載入中…")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            .padding(.top, 48)
                        } else if let err = viewModel.errorMessage {
                            VStack(spacing: 16) {
                                Text(err)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.error)
                                    .multilineTextAlignment(.center)
                                Button("重試") {
                                    Task { await viewModel.load() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColor.primary)
                            }
                            .padding(CardChrome.padding)
                        } else if let desk = viewModel.currentDesk, let founder = viewModel.currentFounder {
                            VStack(spacing: 20) {
                                ExploreFounderCard(
                                    founder: founder,
                                    connectInFlight: connectInFlight,
                                    connectBanner: connectBanner,
                                    onConnect: { Task { await sendConnectionInvite(to: founder.id) } }
                                )

                                DeskCardView(desk: desk, founder: founder) {
                                    Task { await viewModel.viewAgain() }
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
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(AppColor.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(AppColor.textSecondary)
                                    }
                                    .padding(CardChrome.padding)
                                    .deskerElevatedCard()
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, CardChrome.padding)
                        } else {
                            exploreEmpty
                                .padding(.horizontal, CardChrome.padding)
                        }
                    }
                    .padding(.bottom, CardChrome.sectionSpacing)
                }
                .refreshable { await viewModel.load() }
            }
            .background(AppColor.background.ignoresSafeArea())
            .task { await viewModel.load() }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.applyFiltersReselectingIfNeeded()
            }
            .onChange(of: viewModel.selectedFilterChip) { _, _ in
                viewModel.applyFiltersReselectingIfNeeded()
            }
            .deskerHiddenNavigationBar()
        }
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
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
                            HapticFeedback.light()
                            viewModel.selectedFilterChip = chip
                            viewModel.applyFiltersReselectingIfNeeded()
                        } label: {
                            Text(chip)
                                .font(.subheadline.weight(on ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(on ? AppColor.primary : AppColor.cardBackground)
                                )
                                .foregroundStyle(on ? Color.white : AppColor.textPrimary)
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
        ContentUnavailableView(
            "暫時沒有內容",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("試試調整搜尋或篩選條件")
        )
        .padding(.top, 40)
    }

    private func sendConnectionInvite(to founderId: UUID) async {
        connectBanner = nil
        guard let uid = auth.currentUser?.id else {
            connectBanner = "請先登入"
            return
        }
        if founderId == uid {
            connectBanner = "這是你本人"
            return
        }
        connectInFlight = true
        defer { connectInFlight = false }
        do {
            if try await connectionsRepo.areConnected(uid, founderId) {
                connectBanner = "你們已連接"
                HapticFeedback.success()
                return
            }
            try await connectionsRepo.sendConnectionInvite(from: uid, to: founderId)
            connectBanner = "連接邀請已送出"
            HapticFeedback.success()
        } catch {
            connectBanner = error.localizedDescription
            HapticFeedback.error()
        }
    }
}

// MARK: - Founder user card (Explore)

private struct ExploreFounderCard: View {
    let founder: UserProfile
    let connectInFlight: Bool
    let connectBanner: String?
    let onConnect: () -> Void

    private var skillChips: [String] {
        let s = Array(founder.skills.prefix(4))
        if s.isEmpty { return Array(founder.industryTags.prefix(3)) }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                founderAvatar
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(founder.displayName.isEmpty ? "創辦人" : founder.displayName)
                            .font(.title3.bold())
                            .foregroundStyle(AppColor.textPrimary)
                        if founder.verificationBadgeStyle != nil {
                            Image(systemName: "star.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColor.gold)
                                .shadow(color: AppColor.gold.opacity(0.45), radius: 2, y: 0)
                        }
                    }
                    roleBadge
                    if let bio = founder.bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let detailed = founder.detailedBio?.trimmingCharacters(in: .whitespacesAndNewlines), !detailed.isEmpty {
                        Text(detailed)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(3)
                    }
                }
            }

            if !skillChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(skillChips, id: \.self) { skill in
                            Text(skill)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppColor.primary.opacity(0.12))
                                .foregroundStyle(AppColor.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Button(action: onConnect) {
                HStack {
                    if connectInFlight {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("連接")
                            .font(.headline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.brandGradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .deskerButtonShadow()
            .disabled(connectInFlight)

            if let connectBanner {
                Text(connectBanner)
                    .font(.footnote)
                    .foregroundStyle(connectBanner.contains("失敗") || connectBanner.contains("錯誤") ? AppColor.error : AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
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
                        placeholderAvatar
                    case .empty:
                        ProgressView()
                            .tint(AppColor.primary)
                    @unknown default:
                        placeholderAvatar
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
            } else {
                placeholderAvatar
            }
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.crop.rectangle.fill")
            .font(.system(size: 56))
            .symbolRenderingMode(.palette)
            .foregroundStyle(AppColor.primary, AppColor.secondary.opacity(0.85))
            .frame(width: 72, height: 72)
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
