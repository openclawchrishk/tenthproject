import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @State private var industryTags: Set<String> = []
    @State private var skills: Set<String> = []
    @State private var needs: Set<String> = []
    @State private var usernameDraft = ""
    @State private var isSaving = false
    @State private var banner: String?
    @State private var showShareInvite = false
    @State private var showProfileShareOptions = false
    @State private var showVerificationSheet = false
    @State private var verificationKind: VerificationKindUI = .investor
    @State private var expertDomainDraft = ""
    @State private var verificationDocURL: URL?
    @State private var showDocImporter = false
    @State private var verificationBusy = false
    @State private var showIGExportShare = false
    @State private var igExportShareItems: [Any] = []
    @State private var showPremium = false
    @State private var referralCount = 0
    @State private var deskProjectCount = 0
    @State private var connectionCount = 0

    private let userRepo = UserRepository()
    private let referralRepo = ReferralRepository()
    private let deskRepo = DeskRepository()
    private let connectionRepo = ConnectionRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "個人資料",
                    subtitle: auth.currentUser?.displayName ?? ""
                )
                if let user = auth.currentUser {
                    profileHero(user)
                        .padding(.horizontal, CardChrome.padding)
                        .padding(.bottom, 12)
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
                    }
                    .tint(AppColor.primary)
                    .scrollContentBackground(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        profileSaveBar
                    }
                    .overlay {
                        if isSaving {
                            ZStack {
                                Color.black.opacity(0.06).ignoresSafeArea()
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .tint(AppColor.primary)
                                    Text("儲存中...")
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
                            .allowsHitTesting(false)
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
            await loadProfileStats()
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
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
        .sheet(isPresented: $showProfileShareOptions) {
            if let user = auth.currentUser {
                DeskerShareOptionsSheet(
                    title: "分享個人檔案",
                    url: profileURL(for: user),
                    onBuildIGCardShareItems: { await buildProfileIGShareItems(for: user) }
                )
            }
        }
        .sheet(isPresented: $showVerificationSheet) {
            verificationRequestForm
        }
        .fileImporter(
            isPresented: $showDocImporter,
            allowedContentTypes: [.pdf, UTType.image],
            allowsMultipleSelection: false
        ) { result in
            verificationDocURL = try? result.get().first
        }
        .sheet(isPresented: $showIGExportShare) {
            ShareSheetView(items: igExportShareItems)
        }
    }

    @ViewBuilder
    private func profileHero(_ user: UserProfile) -> some View {
        VStack(spacing: 16) {
            ZStack {
                LinearGradient(
                    colors: [AppColor.primary.opacity(0.22), AppColor.secondary.opacity(0.12), AppColor.background],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous))
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                avatarStack(user)
                    .offset(y: 44)
            }
            .padding(.bottom, 44)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(user.displayName.isEmpty ? "—" : user.displayName)
                        .font(.title.bold())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if user.verificationBadgeStyle != nil {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.gold)
                    }
                    if let v = user.verificationBadgeStyle {
                        VerificationBadgeView(style: v)
                    }
                }
                levelBadgeRow(user)
                Text(user.role.localizedName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RoleBadgePalette.color(for: user.role))
            }
            .padding(.top, 8)

            HStack(spacing: 0) {
                statCell(title: "專案", value: "\(deskProjectCount)")
                Divider().frame(height: 36)
                statCell(title: "連接", value: "\(connectionCount)")
                Divider().frame(height: 36)
                statCell(title: "完整度", value: "\(Int(round(user.profileCompleteness * 100)))%")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
            )
        }
    }

    private func levelBadgeRow(_ user: UserProfile) -> some View {
        Group {
            if user.level >= .level3 {
                Text(user.level.localizedTitle)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [AppColor.gold.opacity(0.95), AppColor.gold.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(AppColor.textPrimary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            } else {
                Text(user.level.localizedTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColor.secondaryGroupedSurface)
                    .foregroundStyle(AppColor.textPrimary)
                    .clipShape(Capsule())
            }
        }
    }

    private func avatarStack(_ user: UserProfile) -> some View {
        ZStack {
                if let s = user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
                   let url = URL(string: s) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderAvatar(for: user)
                        case .empty:
                            ProgressView()
                                .tint(AppColor.primary)
                        @unknown default:
                            placeholderAvatar(for: user)
                        }
                    }
                    .frame(width: 112, height: 112)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(user.isPremium ? AppColor.gold : AppColor.textTertiary.opacity(0.4), lineWidth: user.isPremium ? 4 : 2)
                    )
                } else {
                    placeholderAvatar(for: user)
                        .overlay(
                            Circle()
                                .stroke(user.isPremium ? AppColor.gold : AppColor.textTertiary.opacity(0.4), lineWidth: user.isPremium ? 4 : 2)
                        )
                }
        }
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func placeholderAvatar(for user: UserProfile) -> some View {
        let name = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let initials = profileInitials(from: name)
        return ZStack {
            Circle()
                .fill(AppColor.primary)
                .frame(width: 112, height: 112)
            Text(initials)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
        }
    }

    private func profileInitials(from name: String) -> String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        let s = String(name.prefix(2))
        return s.isEmpty ? "?" : s.uppercased()
    }

    @ViewBuilder
    private func profileCompletenessSection(_ user: UserProfile) -> some View {
        Section {
            let p = user.profileCompleteness
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("資料完整度")
                        .font(.headline)
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
                    verificationKind = .investor
                    expertDomainDraft = ""
                    verificationDocURL = nil
                    showVerificationSheet = true
                    HapticFeedback.light()
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
                showProfileShareOptions = true
                HapticFeedback.light()
            } label: {
                Label("分享個人檔案", systemImage: "link")
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
            HStack {
                Text("產業、技能與需求")
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.textTertiary)
            }
            .foregroundStyle(AppColor.textSecondary)
        }
        .listRowBackground(AppColor.cardBackground)
    }

    private var profileSaveBar: some View {
        Group {
            if auth.currentUser != nil {
                Button {
                    HapticFeedback.medium()
                    Task { await save() }
                } label: {
                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                            Spacer()
                        }
                        .frame(height: 50)
                    } else {
                        Text("儲存變更")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .disabled(isSaving)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [AppColor.primary, AppColor.secondary], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                .deskerButtonShadow()
                .buttonStyle(DeskerButtonPressStyle())
                .padding(.horizontal, CardChrome.padding)
                .padding(.vertical, 10)
                .background(AppColor.background.opacity(0.98))
            }
        }
    }

    private func profileURL(for user: UserProfile) -> URL {
        PublicLinks.profilePublicURL(for: user)
    }

    private func loadReferrals() async {
        guard let uid = auth.currentUser?.id else { return }
        referralCount = (try? await referralRepo.fetchReferralCount(for: uid)) ?? 0
    }

    private func loadProfileStats() async {
        guard let uid = auth.currentUser?.id else {
            deskProjectCount = 0
            connectionCount = 0
            return
        }
        do {
            let desks = try await deskRepo.fetchDesksForFounder(founderId: uid)
            deskProjectCount = desks.count
        } catch {
            deskProjectCount = 0
        }
        do {
            let conns = try await connectionRepo.fetchConnections(userId: uid)
            connectionCount = conns.count
        } catch {
            connectionCount = 0
        }
    }

    private func exportProfileCard(_ user: UserProfile) async {
        #if os(iOS)
        var avatar: UIImage?
        if let s = user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           let url = URL(string: s) {
            avatar = await IGCardExportService.loadUIImage(from: url)
        }
        guard let image = IGCardExportService.renderProfileCard(user: user, avatarImage: avatar) else {
            banner = "無法產生圖片"
            return
        }
        do {
            try await IGCardExportService.saveToPhotoLibrary(image)
            banner = "已儲存到相簿，可分享"
            igExportShareItems = [image, profileURL(for: user)]
            showIGExportShare = true
            HapticFeedback.success()
        } catch {
            banner = "儲存失敗：\(error.localizedDescription)，仍可分享"
            igExportShareItems = [image, profileURL(for: user)]
            showIGExportShare = true
            HapticFeedback.error()
        }
        #endif
    }

    private var verificationRequestForm: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("認證類型", selection: $verificationKind) {
                        ForEach(VerificationKindUI.allCases, id: \.self) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                }
                if verificationKind == .expert {
                    Section {
                        TextField("專業領域（例：香港執業律師）", text: $expertDomainDraft)
                            .foregroundStyle(AppColor.textPrimary)
                        Button {
                            showDocImporter = true
                            HapticFeedback.light()
                        } label: {
                            Label(
                                verificationDocURL?.lastPathComponent ?? "選擇證明文件（PDF／圖片）",
                                systemImage: "doc.badge.plus"
                            )
                        }
                    } header: {
                        Text("專家認證")
                    }
                }
                Section {
                    Text("提交後狀態將為「審核中」。文件上傳為本機選擇示意，正式上線可對接 Storage。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("申請官方認證")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showVerificationSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") {
                        Task { await submitVerificationFromSheet() }
                    }
                    .disabled(verificationBusy)
                }
            }
        }
    }

    private func submitVerificationFromSheet() async {
        guard let uid = auth.currentUser?.id else { return }
        if verificationKind == .expert {
            let d = expertDomainDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if d.isEmpty {
                banner = "請填寫專業領域"
                HapticFeedback.error()
                return
            }
        }
        verificationBusy = true
        defer { verificationBusy = false }
        do {
            let kind: UserRepository.VerificationApplicationKind =
                verificationKind == .investor ? .investor : .expert
            try await userRepo.submitVerificationApplication(
                userId: uid,
                kind: kind,
                expertDomain: verificationKind == .expert ? expertDomainDraft : nil,
                documentNote: verificationDocURL?.path
            )
            showVerificationSheet = false
            await auth.refreshProfile()
            banner = "已提交認證申請"
            toast.show(.success, "已提交認證申請")
            HapticFeedback.success()
        } catch {
            banner = "提交失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
    }

    private func buildProfileIGShareItems(for user: UserProfile) async -> [Any]? {
        #if os(iOS)
        var avatar: UIImage?
        if let s = user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           let url = URL(string: s) {
            avatar = await IGCardExportService.loadUIImage(from: url)
        }
        guard let image = IGCardExportService.renderProfileCard(user: user, avatarImage: avatar) else {
            return nil
        }
        return [image, profileURL(for: user)]
        #else
        return nil
        #endif
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
            toast.show(.success, "已儲存")
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

private enum VerificationKindUI: String, CaseIterable {
    case investor = "投資者"
    case expert = "專家"
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(on ? accent.opacity(0.18) : accent.opacity(0.1))
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
