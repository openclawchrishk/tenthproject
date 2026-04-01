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
    @State private var activeDeskCount = 0
    @State private var archivedDeskCount = 0
    @State private var connectionCount = 0
    @State private var bioDraft = ""
    @State private var detailedBioDraft = ""
    @State private var linkedInDraft = ""
    @State private var websiteDraft = ""
    @State private var interestTags: Set<String> = []
    @State private var scrollToSection: String?

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
                if auth.currentUser != nil, !DeskerUXPreferences.tipProfileDismissed {
                    profileFirstVisitTip
                        .padding(.horizontal, CardChrome.padding)
                        .padding(.bottom, 8)
                }
                if let user = auth.currentUser {
                    profileHero(user)
                        .padding(.horizontal, CardChrome.padding)
                        .padding(.bottom, 12)
                    verificationStatusCallout(user)
                        .padding(.horizontal, CardChrome.padding)
                        .padding(.bottom, 10)
                    ScrollViewReader { proxy in
                        Form {
                            profileCompletenessSection(user)
                            levelAndBadgesSection(user)
                            inviteAndReferralSection(user)
                            verificationAndPremiumSection(user)
                            exportSection(user)
                            accountSection(user)
                            bioAndLinksSection()
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
                        .onChange(of: scrollToSection) { _, id in
                            guard let id else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                                scrollToSection = nil
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        profileSaveBar
                    }
                    .overlay {
                        if isSaving {
                            ZStack {
                                Color.black.opacity(0.3)
                                    .ignoresSafeArea()
                                ProgressView()
                                    .tint(AppColor.primary)
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
            await loadProfileStats()
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
            syncFromProfile()
        }
        .sheet(isPresented: $showPremium, onDismiss: {}) {
            PremiumUpgradeSheet()
        }
        .sheet(isPresented: $showShareInvite, onDismiss: {}) {
            if let user = auth.currentUser {
                ShareSheetView(items: [PublicLinks.inviteURL(invitationCode: user.invitationCode)])
            }
        }
        .sheet(isPresented: $showProfileShareOptions, onDismiss: {}) {
            if let user = auth.currentUser {
                DeskerShareOptionsSheet(
                    title: "分享個人檔案",
                    url: profileURL(for: user),
                    onBuildIGCardShareItems: { await buildProfileIGShareItems(for: user) }
                )
                .deskerSheetSpringContent()
            }
        }
        .sheet(isPresented: $showVerificationSheet, onDismiss: {}) {
            verificationRequestForm
                .deskerSheetSpringContent()
        }
        .fileImporter(
            isPresented: $showDocImporter,
            allowedContentTypes: [.pdf, UTType.image],
            allowsMultipleSelection: false
        ) { result in
            verificationDocURL = try? result.get().first
        }
        .sheet(isPresented: $showIGExportShare, onDismiss: {}) {
            ShareSheetView(items: igExportShareItems)
        }
    }

    @ViewBuilder
    private var profileFirstVisitTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.text.rectangle.fill")
                .foregroundStyle(AppColor.primary)
            Text("完善標籤與簡介可提升曝光；完成度越高，越易被其他創業者發現。")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: 560, alignment: .leading)
            Button {
                DeskerUXPreferences.tipProfileDismissed = true
                HapticFeedback.selection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppColor.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                .fill(AppColor.primary.opacity(0.08))
        )
    }

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
                    Text((user.displayName.isEmpty ? "—" : user.displayName).deskerTruncated(maxLength: 20))
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
                completenessTierBadgeRow(for: user)
                Text(user.role.localizedName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RoleBadgePalette.color(for: user.role))
            }
            .padding(.top, 8)

            HStack(spacing: 0) {
                deskStatColumn
                Divider().frame(height: 52)
                connectionMilestoneColumn()
                Divider().frame(height: 52)
                completenessStatColumn(user: user)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
            )

            profileEditShortcutsRow()
                .padding(.top, 6)
        }
    }

    private func profileEditShortcutsRow() -> some View {
        HStack(spacing: 10) {
            Button {
                HapticFeedback.light()
                scrollToSection = "section_bio"
            } label: {
                Label("簡介", systemImage: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .tint(AppColor.primary)

            Button {
                HapticFeedback.light()
                scrollToSection = "section_tags"
            } label: {
                Label("標籤", systemImage: "tag.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(AppColor.secondary)

            Button {
                HapticFeedback.light()
                scrollToSection = "section_completeness"
            } label: {
                Label("完整度", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(AppColor.gold)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func verificationStatusCallout(_ user: UserProfile) -> some View {
        switch user.verificationStatus {
        case .verifiedInvestor, .verifiedExpert:
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(AppColor.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("官方認證")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(user.verificationStatus == .verifiedInvestor ? "投資者認證" : "專家認證")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.teal.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .stroke(AppColor.teal.opacity(0.35), lineWidth: 1)
            )
        case .pending:
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.title2)
                    .foregroundStyle(AppColor.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("認證審核中")
                        .font(.subheadline.weight(.bold))
                    Text("我們會盡快處理你的申請，請留意通知。")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.gold.opacity(0.1))
            )
        case .rejected:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColor.error)
                    Text("認證未通過")
                        .font(.subheadline.weight(.bold))
                }
                Text("可於下方「升級與認證」重新提交資料。")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                Button {
                    HapticFeedback.light()
                    scrollToSection = "section_verification"
                } label: {
                    Text("前往認證區域")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.primary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.error.opacity(0.08))
            )
        case .none:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(AppColor.primary)
                    Text("尚未申請官方認證")
                        .font(.subheadline.weight(.bold))
                }
                Text("完成認證可提升信任度與曝光。")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                Button {
                    HapticFeedback.light()
                    scrollToSection = "section_verification"
                } label: {
                    Text("了解認證")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(AppColor.primary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.primary.opacity(0.08))
            )
        }
    }

    /// Visual tier from profile completeness (Lv1 無章 / Lv2 銀 / Lv3 金).
    private func completenessTierBadgeRow(for user: UserProfile) -> some View {
        let tier = ProfileCompletenessTier.from(completeness: user.profileCompleteness)
        return HStack(spacing: 6) {
            switch tier {
            case .starter:
                Text(tier.localizedTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColor.secondaryGroupedSurface)
                    .foregroundStyle(AppColor.textSecondary)
                    .clipShape(Capsule())
            case .rising:
                Image(systemName: "medal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(white: 0.72))
                    .shadow(color: .white.opacity(0.35), radius: 0, y: 0)
                Text(tier.localizedTitle)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color(white: 0.88), Color(white: 0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(AppColor.textPrimary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
            case .champion:
                Image(systemName: "medal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.gold)
                Text(tier.localizedTitle)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [AppColor.gold.opacity(0.95), AppColor.gold.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(AppColor.textPrimary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
            }
        }
    }

    private var deskStatColumn: some View {
        VStack(spacing: 4) {
            Text("\(deskProjectCount)")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text("已建立 \(deskProjectCount) 個Desk")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            if deskProjectCount > 0 {
                Text("活躍 \(activeDeskCount) · 封存 \(archivedDeskCount)")
                    .font(.caption2)
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func connectionMilestoneColumn() -> some View {
        let next = ConnectionMilestone.next(after: connectionCount)
        return VStack(spacing: 4) {
            Text("\(connectionCount)")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text("已連接 \(connectionCount) 人")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            if let next {
                let left = max(0, next - connectionCount)
                Text("下一里程碑 \(next) 人（尚差 \(left)）")
                    .font(.caption2)
                    .foregroundStyle(AppColor.textTertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text("已達最高里程碑")
                    .font(.caption2)
                    .foregroundStyle(AppColor.teal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func completenessStatColumn(user: UserProfile) -> some View {
        let pct = Int(round(user.profileCompleteness * 100))
        return VStack(spacing: 4) {
            Text("\(pct)%")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.primary)
            Text("完整度")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
            Text("\(pct)% 完成")
                .font(.caption2)
                .foregroundStyle(AppColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func avatarStack(_ user: UserProfile) -> some View {
        ZStack {
                if let s = user.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
                   let url = URL(string: s) {
                    CachedAsyncImage(url: url, maxPixelDimension: 400) { phase in
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
            let missing = ProfileCompleteness.missingItems(for: user)
            let pct = Int(round(p * 100))
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("資料完整度")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text("\(pct)% 完成")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                }
                ProfileCompletenessBar(value: p)
                if p < 1 {
                    Label("完成後獲得金牌創業者標誌與更高曝光", systemImage: "medal.fill")
                        .font(.caption.weight(.semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.gold, AppColor.textSecondary)
                }
                if p < 1 {
                    Text("尚欠項目（點一下前往編輯）")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(missing.prefix(8).enumerated()), id: \.offset) { _, item in
                            Button {
                                HapticFeedback.light()
                                scrollToSection = profileScrollSectionId(forMissingFieldTitle: item.0)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: ProfileCompleteness.iconName(forMissingTitle: item.0))
                                        .font(.body)
                                        .foregroundStyle(AppColor.primary)
                                        .frame(width: 24, alignment: .center)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.0)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(AppColor.textPrimary)
                                        Text(item.1)
                                            .font(.caption)
                                            .foregroundStyle(AppColor.textSecondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppColor.textTertiary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        if missing.count > 8 {
                            Text("還有 \(missing.count - 8) 項…")
                                .font(.caption)
                                .foregroundStyle(AppColor.textTertiary)
                        }
                    }
                }
                if p >= 1 {
                    Label("檔案已完整", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.gold, AppColor.primary)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(AppColor.cardBackground)
        .id("section_completeness")
    }

    private func profileScrollSectionId(forMissingFieldTitle title: String) -> String {
        switch title {
        case "頭像":
            return "section_completeness"
        case "一句簡介", "詳細介紹", "LinkedIn", "網站", "興趣標籤":
            return "section_bio"
        case "產業標籤", "技能", "需求":
            return "section_tags"
        default:
            return "section_completeness"
        }
    }

    @ViewBuilder
    private func levelAndBadgesSection(_ user: UserProfile) -> some View {
        Section("等級與標章") {
            let tier = ProfileCompletenessTier.from(completeness: user.profileCompleteness)
            LabeledContent("帳戶 Level（功能額度）") {
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
            LabeledContent("檔案完整度等級") {
                Text("\(tier.localizedTitle)（\(Int(round(user.profileCompleteness * 100)))%）")
                    .foregroundStyle(AppColor.textPrimary)
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
        .id("section_level")
    }

    @ViewBuilder
    private func inviteAndReferralSection(_ user: UserProfile) -> some View {
        Section("邀請與推薦") {
            LabeledContent("推薦碼（個人檔案）") {
                Text(user.invitationCode.isEmpty ? "—" : user.invitationCode)
                    .font(.body.monospaced())
                    .foregroundStyle(AppColor.textPrimary)
            }
            LabeledContent("成功推薦人數") {
                Text("\(referralCount) 人")
                    .foregroundStyle(AppColor.textPrimary)
            }
            LabeledContent("累積獎勵（示意）") {
                Text("Premium 試用天數、能見度加成 — 正式上線後依推薦數發放")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                showShareInvite = true
                HapticFeedback.light()
                DeskerAnalytics.track(.userShareProfile, parameters: ["context": "invite_friend"])
            } label: {
                Label("邀請朋友", systemImage: "square.and.arrow.up")
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
        .id("section_verification")
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
        .id("section_tags")
    }

    @ViewBuilder
    private func bioAndLinksSection() -> some View {
        Section {
            TextField("一句簡介", text: $bioDraft, axis: .vertical)
                .lineLimit(2...5)
                .foregroundStyle(AppColor.textPrimary)
            TextField("詳細介紹", text: $detailedBioDraft, axis: .vertical)
                .lineLimit(3...8)
                .foregroundStyle(AppColor.textPrimary)
            TextField("LinkedIn URL", text: $linkedInDraft)
                .foregroundStyle(AppColor.textPrimary)
#if os(iOS)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
#endif
            TextField("網站 URL", text: $websiteDraft)
                .foregroundStyle(AppColor.textPrimary)
#if os(iOS)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
#endif
            TagSection(
                title: "興趣標籤",
                subtitle: "點選以編輯，完成後按儲存",
                options: OnboardingViewModel.interestOptions,
                selection: $interestTags,
                accent: AppColor.teal
            )
        } header: {
            Text("簡介與連結")
        }
        .listRowBackground(AppColor.cardBackground)
        .id("section_bio")
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
                .opacity(isSaving ? 0.5 : 1)
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
            activeDeskCount = 0
            archivedDeskCount = 0
            connectionCount = 0
            return
        }
        do {
            let desks = try await deskRepo.fetchDesksForFounder(founderId: uid)
            deskProjectCount = desks.count
            activeDeskCount = desks.filter { $0.status != .archived }.count
            archivedDeskCount = desks.filter { $0.status == .archived }.count
        } catch {
            deskProjectCount = 0
            activeDeskCount = 0
            archivedDeskCount = 0
        }
        do {
            let conns = try await connectionRepo.fetchConnections(userId: uid)
            connectionCount = conns.count
        } catch {
            connectionCount = 0
        }
        if let u = auth.currentUser {
            DeskerAnalytics.updateUserSnapshot(
                userId: u.id,
                level: u.level.rawValue,
                completenessPercent: Int(round(u.profileCompleteness * 100)),
                connectionCount: connectionCount,
                deskCount: deskProjectCount
            )
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
            DeskerAnalytics.track(.userExportIGCard)
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
            banner = "提交失敗：\(APIErrorMessages.userFacingMessage(for: error))"
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
        bioDraft = u.bio ?? ""
        detailedBioDraft = u.detailedBio ?? ""
        linkedInDraft = u.linkedInUrl ?? ""
        websiteDraft = u.websiteUrl ?? ""
        interestTags = Set(u.interestTags)
    }

    private func save() async {
        guard var profile = auth.currentUser else { return }
        let u = usernameDraft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !u.isEmpty && !ProfileFieldValidation.isValidUsername(u) {
            banner = "使用者名稱只可使用英文、數字及底線（最多 \(ProfileFieldValidation.usernameMaxLength) 字）"
            HapticFeedback.error()
            return
        }
        isSaving = true
        banner = nil
        defer { isSaving = false }
        do {
            profile.industryTags = Array(industryTags)
            profile.skills = Array(skills)
            profile.needs = Array(needs)
            profile.interestTags = Array(interestTags).sorted()
            profile.bio = Self.nilIfEmpty(bioDraft)
            profile.detailedBio = Self.nilIfEmpty(detailedBioDraft)
            profile.linkedInUrl = Self.nilIfEmpty(linkedInDraft)
            profile.websiteUrl = Self.nilIfEmpty(websiteDraft)
            profile.username = u.isEmpty ? nil : u
            usernameDraft = u.isEmpty ? "" : u
            if let w = profile.websiteUrl, !ProfileFieldValidation.isValidOptionalHTTPURLString(w) {
                banner = "網站請使用 http 或 https 完整網址"
                HapticFeedback.error()
                return
            }
            if let li = profile.linkedInUrl, !ProfileFieldValidation.isValidOptionalHTTPURLString(li) {
                banner = "LinkedIn 請使用 http 或 https 完整網址"
                HapticFeedback.error()
                return
            }
            try await userRepo.upsertUser(profile)
            await auth.refreshProfile()
            await loadReferrals()
            banner = "已儲存"
            toast.show(.success, "已儲存")
            HapticFeedback.success()
        } catch {
            banner = "儲存失敗：\(APIErrorMessages.userFacingMessage(for: error))"
            HapticFeedback.error()
        }
    }

    private static func nilIfEmpty(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
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
