import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var industryTags: Set<String> = []
    @State private var skills: Set<String> = []
    @State private var needs: Set<String> = []
    @State private var usernameDraft = ""
    @State private var isSaving = false
    @State private var banner: String?
    @State private var showShareInvite = false
    @State private var showShareProfile = false
    @State private var showPremium = false
    @State private var referralCount = 0

    private let userRepo = UserRepository()
    private let referralRepo = ReferralRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "個人資料",
                    subtitle: auth.currentUser?.displayName ?? ""
                )
                if let user = auth.currentUser {
                    Form {
                        profileCompletenessSection(user)
                        levelAndBadgesSection(user)
                        inviteAndReferralSection(user)
                        verificationAndPremiumSection(user)
                        exportSection(user)
                        accountSection(user)
                        tagsSection(user)
                        if let banner {
                            Section {
                                Text(banner)
                                    .font(.footnote)
                                    .foregroundStyle(bannerForeground(banner))
                            }
                            .listRowBackground(AppColor.cardBackground)
                        }
                        saveSection
                    }
                    .tint(AppColor.primary)
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if isSaving {
                            ZStack {
                                Color.black.opacity(0.06).ignoresSafeArea()
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .tint(AppColor.primary)
                                    Text("儲存中…")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                                .padding(28)
                                .background(
                                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .deskerButtonShadow()
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("尚未載入資料", systemImage: "person.crop.circle.badge.questionmark")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .background(AppColor.background.ignoresSafeArea())
            .deskerInlineNavigationTitle()
        }
        .task {
            await auth.refreshProfile()
            syncFromProfile()
            await loadReferrals()
        }
        .onChange(of: auth.currentUser?.id) { _ in
            syncFromProfile()
        }
        .sheet(isPresented: $showPremium) {
            PremiumUpgradeSheet()
        }
        .sheet(isPresented: $showShareInvite) {
            if let user = auth.currentUser {
                let link = URL(string: "\(PublicLinks.baseURLString)/join?code=\(user.invitationCode)")!
                ShareSheetView(items: [link])
            }
        }
        .sheet(isPresented: $showShareProfile) {
            if let user = auth.currentUser {
                let url = profileURL(for: user)
                ShareSheetView(items: [url])
            }
        }
    }

    @ViewBuilder
    private func profileCompletenessSection(_ user: UserProfile) -> some View {
        Section {
            let p = user.profileCompleteness
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("資料完整度")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text("\(Int(round(p * 100)))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                }
                ProfileCompletenessBar(value: p)
                if p >= 1 {
                    Label("Profile 完整", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.gold, AppColor.primary)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(AppColor.cardBackground)
    }

    @ViewBuilder
    private func levelAndBadgesSection(_ user: UserProfile) -> some View {
        Section("等級與標章") {
            LabeledContent("Level") {
                HStack(spacing: 8) {
                    Text(user.level.localizedTitle)
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    if user.isPremium {
                        Text("Premium")
                            .font(.caption2.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(
                                    colors: [AppColor.gold.opacity(0.95), AppColor.gold.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(AppColor.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                    }
                }
            }
            LabeledContent("成員上限（Desk）") {
                Text("\(user.level.deskMemberLimit) 人")
                    .foregroundStyle(AppColor.textPrimary)
            }
            if let v = user.verificationBadgeStyle {
                HStack {
                    Text("官方認證")
                    Spacer()
                    VerificationBadgeView(style: v)
                }
            }
        }
        .listRowBackground(AppColor.cardBackground)
    }

    @ViewBuilder
    private func inviteAndReferralSection(_ user: UserProfile) -> some View {
        Section("邀請與推薦") {
            LabeledContent("邀請碼") {
                Text(user.invitationCode.isEmpty ? "—" : user.invitationCode)
                    .font(.body.monospaced())
                    .foregroundStyle(AppColor.textPrimary)
            }
            LabeledContent("成功推薦") {
                Text("\(referralCount) 人")
                    .foregroundStyle(AppColor.textPrimary)
            }
            Button {
                showShareInvite = true
                HapticFeedback.light()
            } label: {
                Label("分享邀請連結", systemImage: "square.and.arrow.up")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.primary, AppColor.secondary)
            }
        }
        .listRowBackground(AppColor.cardBackground)
    }

    @ViewBuilder
    private func verificationAndPremiumSection(_ user: UserProfile) -> some View {
        Section("升級與認證") {
            if user.level < .level3 {
                Button {
                    showPremium = true
                    HapticFeedback.light()
                } label: {
                    Label("升級至 Level 3（Premium）", systemImage: "crown.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.gold, AppColor.primary)
                }
            }
            if user.verificationStatus == .none || user.verificationStatus == .rejected {
                Button {
                    Task { await submitVerification() }
                } label: {
                    Label("申請官方認證", systemImage: "checkmark.shield")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.secondary, AppColor.teal)
                }
            } else if user.verificationStatus == .pending {
                Text("認證審核中")
                    .foregroundStyle(AppColor.textSecondary)
            }
            PushNotificationPlaceholderView()
        }
        .listRowBackground(AppColor.cardBackground)
    }

    @ViewBuilder
    private func exportSection(_ user: UserProfile) -> some View {
        Section("分享與匯出") {
            Button {
                showShareProfile = true
                HapticFeedback.light()
            } label: {
                Label("分享公開檔案連結", systemImage: "link")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.primary, AppColor.secondary)
            }
            Button {
                Task { await exportProfileCard(user) }
            } label: {
                Label("匯出 IG 限動個人卡（1080×1350）", systemImage: "photo.on.rectangle.angled")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.secondary, AppColor.teal)
            }
        }
        .listRowBackground(AppColor.cardBackground)
    }

    @ViewBuilder
    private func accountSection(_ user: UserProfile) -> some View {
        Section("帳戶") {
            TextField("使用者名稱（公開連結）", text: $usernameDraft)
                .deskerTextFieldNoAutocaps()
                .autocorrectionDisabled()
                .foregroundStyle(AppColor.textPrimary)
            LabeledContent("名稱") {
                Text(user.displayName)
                    .foregroundStyle(AppColor.textPrimary)
            }
            LabeledContent("角色") {
                Text(user.role.localizedName)
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .listRowBackground(AppColor.cardBackground)
    }

    @ViewBuilder
    private func tagsSection(_ user: UserProfile) -> some View {
        Section {
            TagSection(
                title: "產業標籤",
                subtitle: "點選以編輯，完成後按儲存",
                options: OnboardingViewModel.industryOptions,
                selection: $industryTags,
                accent: AppColor.primary
            )
            TagSection(
                title: "技能",
                subtitle: "",
                options: OnboardingViewModel.skillOptions,
                selection: $skills,
                accent: AppColor.secondary
            )
            TagSection(
                title: "需求",
                subtitle: "",
                options: OnboardingViewModel.needOptions,
                selection: $needs,
                accent: AppColor.gold
            )
        } header: {
            Text("產業、技能與需求")
                .foregroundStyle(AppColor.textSecondary)
        }
        .listRowBackground(AppColor.cardBackground)
    }

    private var saveSection: some View {
        Section {
            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                } else {
                    Text("儲存變更")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .disabled(isSaving)
            .listRowBackground(
                LinearGradient(colors: [AppColor.primary, AppColor.secondary], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
        }
    }

    private func profileURL(for user: UserProfile) -> URL {
        let handle = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !handle.isEmpty {
            return PublicLinks.profileURL(username: handle)
        }
        return URL(string: "\(PublicLinks.baseURLString)/u/\(user.id.uuidString.lowercased())")!
    }

    private func loadReferrals() async {
        guard let uid = auth.currentUser?.id else { return }
        referralCount = (try? await referralRepo.fetchReferralCount(for: uid)) ?? 0
    }

    private func exportProfileCard(_ user: UserProfile) async {
        #if os(iOS)
        guard let image = IGCardExportService.renderProfileCard(user: user) else {
            banner = "無法產生圖片"
            return
        }
        do {
            try await IGCardExportService.saveToPhotoLibrary(image)
            banner = "已儲存到相簿"
            HapticFeedback.success()
        } catch {
            banner = "儲存失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
        #endif
    }

    private func submitVerification() async {
        guard let uid = auth.currentUser?.id else { return }
        do {
            try await userRepo.submitVerificationApplication(userId: uid)
            await auth.refreshProfile()
            banner = "已提交認證申請"
            HapticFeedback.success()
        } catch {
            banner = "提交失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
    }

    private func syncFromProfile() {
        guard let u = auth.currentUser else { return }
        industryTags = Set(u.industryTags)
        skills = Set(u.skills)
        needs = Set(u.needs)
        usernameDraft = u.username ?? ""
    }

    private func save() async {
        guard var profile = auth.currentUser else { return }
        isSaving = true
        banner = nil
        defer { isSaving = false }
        do {
            profile.industryTags = Array(industryTags)
            profile.skills = Array(skills)
            profile.needs = Array(needs)
            let u = usernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.username = u.isEmpty ? nil : u
            try await userRepo.upsertUser(profile)
            await auth.refreshProfile()
            await loadReferrals()
            banner = "已儲存"
            HapticFeedback.success()
        } catch {
            banner = "儲存失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
    }

    private func bannerForeground(_ banner: String) -> Color {
        if banner.contains("失敗") { return AppColor.error }
        if banner.contains("已儲存") || banner.contains("已提交") || banner.contains("相簿") { return AppColor.success }
        return AppColor.textSecondary
    }
}

private struct ProfileCompletenessBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.surfaceElevated)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: value >= 1
                                ? [AppColor.teal, AppColor.secondary]
                                : [AppColor.primary, AppColor.gold.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, w * CGFloat(value)))
                    .animation(.easeInOut(duration: 0.45), value: value)
            }
        }
        .frame(height: 10)
    }
}

private struct TagSection: View {
    let title: String
    let subtitle: String
    let options: [String]
    @Binding var selection: Set<String>
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let on = selection.contains(option)
                    Button {
                        if on { selection.remove(option) } else { selection.insert(option) }
                        HapticFeedback.light()
                    } label: {
                        Text(option)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(on ? accent.opacity(0.18) : AppColor.surfaceElevated)
                            .foregroundStyle(on ? accent : AppColor.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                                    .stroke(on ? accent : AppColor.textTertiary.opacity(0.25), lineWidth: on ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
