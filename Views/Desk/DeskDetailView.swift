import SwiftUI
import os

#if os(iOS)
import UIKit
#endif

private let deskDetailLog = Logger(subsystem: "hk.desker", category: "DeskDetail")

/// Full project detail — founder, tags, team, funding, apply / invite.
struct DeskDetailView: View {
    let deskId: UUID

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @State private var desk: Desk?
    @State private var founder: UserProfile?
    @State private var myApplication: DeskApplication?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var inviteeIdText = ""
    @State private var inviteMessage: String?
    @State private var inviteInFlight = false

    @State private var showApplySheet = false
    @State private var applySelectedRole: String = ""
    @State private var applyStatement = ""
    @State private var applyError: String?
    @State private var applyInFlight = false
    @State private var canAccessGroupChat = false
    @State private var showDeskShareOptions = false
    @State private var showDeskReport = false
    @State private var deskExportBanner: String?
    @State private var showDeskExportShare = false
    @State private var deskExportShareItems: [Any] = []
    @State private var aboutExpanded = false
    @State private var deskNotFound = false

    private let deskRepository = DeskRepository()
    private let inviteRepository = InviteRepository()
    private let userRepository = UserRepository()

    private var isFounder: Bool {
        guard let uid = auth.currentUser?.id, let desk else { return false }
        return uid == desk.founderId
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if deskNotFound, !isLoading {
                    VStack(spacing: 18) {
                        ContentUnavailableView(
                            "找不到專案",
                            systemImage: "folder.badge.questionmark",
                            description: Text("此 Desk 可能已移除或連結無效").foregroundStyle(AppColor.textSecondary)
                        )
                        Button {
                            HapticFeedback.light()
                            dismiss()
                        } label: {
                            Text("返回")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.primary)
                        .padding(.horizontal, CardChrome.padding)
                    }
                    .padding()
                } else if let loadError, !isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColor.error)
                        Text(loadError)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.error)
                            .multilineTextAlignment(.center)
                        Button("重試") {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.primary)
                    }
                    .padding()
                } else if let desk {
                    detailScroll(desk)
                } else if !isLoading {
                    ContentUnavailableView("找不到專案", systemImage: "folder")
                } else {
                    Color.clear
                }
            }

            if isLoading {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(AppColor.primary)
                    Text("載入中...")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .allowsHitTesting(false)
            }

            floatingBackButton
        }
        .navigationTitle("專案詳情")
        .deskerInlineNavigationTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showDeskShareOptions = true
                    HapticFeedback.medium()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.primary, AppColor.secondary)
                }
                Button {
                    showDeskReport = true
                    HapticFeedback.medium()
                } label: {
                    Image(systemName: "flag")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.accentOrange, AppColor.primary)
                }
                Button {
                    HapticFeedback.medium()
                    Task { await exportDeskStoryCard() }
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.accentPurple, AppColor.secondary)
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showDeskShareOptions) {
            Group {
                if let desk {
                    DeskerShareOptionsSheet(
                        title: "分享 Desk",
                        url: PublicLinks.deskURL(deskId: desk.id),
                        onBuildIGCardShareItems: { await buildDeskIGCardShareItems() }
                    )
                }
            }
            .deskerSheetSpringContent()
        }
        .sheet(isPresented: $showDeskReport) {
            Group {
                if let desk {
                    ReportSheetView(targetType: .desk, targetId: desk.id) { draft in
                        guard let uid = auth.currentUser?.id else {
                            throw RepositoryError.notAuthenticated
                        }
                        try await ReportBlockRepository().submitReport(draft, reporterId: uid)
                    }
                }
            }
            .deskerSheetSpringContent()
        }
        .sheet(isPresented: $showApplySheet) {
            Group {
                if let desk {
                    applySheet(desk)
                }
            }
            .deskerSheetSpringContent()
        }
        .sheet(isPresented: $showDeskExportShare) {
            ShareSheetView(items: deskExportShareItems)
        }
    }

    private var floatingBackButton: some View {
        Button {
            HapticFeedback.light()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColor.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white))
                .deskerFloatingShadow()
        }
        .buttonStyle(DeskerButtonPressStyle())
        .padding(.leading, 12)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func detailScroll(_ desk: Desk) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CardChrome.sectionSpacing) {
                detailHero(desk)
                    .padding(.horizontal, -CardChrome.padding)
                if let deskExportBanner {
                    Text(deskExportBanner)
                        .font(.caption)
                        .foregroundStyle(deskExportBanner.contains("失敗") ? AppColor.error : AppColor.textSecondary)
                        .padding(.horizontal, CardChrome.padding)
                }
                if let founder {
                    founderBlock(founder)
                }
                shareDeskButton(desk)
                NavigationLink {
                    DeskMembersView(desk: desk)
                } label: {
                    Label("Desk 成員", systemImage: "person.3.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(AppColor.primary)
                        .background(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                                .fill(AppColor.cardBackground)
                                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                        )
                }
                .buttonStyle(.plain)
                aboutProjectSection(desk)
                fundingHighlightBox(desk)
                cardParitySummary(desk)
                skillsNeededTagsSection(desk)
                section(title: "詳細描述", icon: "doc.text", color: AppColor.secondary) {
                    Text(desk.detailedDescription ?? "—")
                        .font(.body)
                        .foregroundStyle(AppColor.textPrimary)
                }
                section(title: "需求與期望", icon: "checklist", color: AppColor.gold) {
                    Text(desk.expectations ?? "—")
                        .font(.body)
                        .foregroundStyle(AppColor.textPrimary)
                }
                recruitingRolesCards(desk)
                section(title: "產業標籤", icon: "tag.fill", color: AppColor.primary) {
                    ColoredDeskTags(tags: desk.industryTags)
                }
                metaRow(desk)
                if canAccessGroupChat {
                    NavigationLink {
                        DeskGroupChatView(desk: desk)
                    } label: {
                        Label("群組聊天", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                                    .fill(AppColor.cardBackground)
                                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                            )
                    }
                    .buttonStyle(.plain)
                }
                if isFounder {
                    inviteBlock(desk)
                }
            }
            .padding(.horizontal, CardChrome.padding)
            .padding(.bottom, visitorBottomPadding(desk))
        }
        .background(AppColor.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActionBar(desk)
        }
    }

    private func detailHero(_ desk: Desk) -> some View {
        ZStack(alignment: .bottomLeading) {
            DeskDetailHeroGradient(deskId: desk.id)
                .frame(maxWidth: .infinity)
                .frame(height: 200)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    statusText(desk.status)
                    Spacer()
                    Text(desk.region)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(desk.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
                Text(desk.pitch)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(CardChrome.padding)
        }
        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous))
        .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
    }

    private func aboutProjectSection(_ desk: Desk) -> some View {
        let pitch = desk.pitch.trimmingCharacters(in: .whitespacesAndNewlines)
        let long = pitch.count > 160
        return VStack(alignment: .leading, spacing: 12) {
            Label("關於此專案", systemImage: "text.alignleft")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text(pitch)
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(4)
                .lineLimit(aboutExpanded ? nil : 5)
            if long {
                Button(aboutExpanded ? "收合" : "顯示更多") {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        aboutExpanded.toggle()
                    }
                    HapticFeedback.selection()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CardChrome.padding)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func fundingHighlightBox(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("資金需求", systemImage: "dollarsign.circle.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.gold)
            Text(desk.fundingNeeds ?? "—")
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CardChrome.padding)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .stroke(AppColor.gold, lineWidth: 2)
        )
        .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
    }

    private func recruitingRolesCards(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("招募角色", systemImage: "person.3.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColor.primary)
            if desk.recruitingRoles.isEmpty {
                Text(desk.skillsSummary)
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                ForEach(desk.recruitingRoles) { role in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                .fill(AppColor.primary.opacity(0.1))
                                .frame(width: 48, height: 48)
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                                .foregroundStyle(AppColor.primary)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(role.title)
                                .font(.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            Text("名額：\(role.count)")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.textSecondary)
                            if let s = role.skillDescription {
                                Text(s)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.textPrimary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(CardChrome.padding)
                    .background(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                            .fill(AppColor.cardBackground)
                            .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                    )
                }
            }
        }
    }

    private func visitorBottomPadding(_ desk: Desk) -> CGFloat {
        if !isFounder, desk.status == .recruiting, auth.currentUser != nil { return 8 }
        return 0
    }

    @ViewBuilder
    private func bottomActionBar(_ desk: Desk) -> some View {
        if isFounder {
            EmptyView()
        } else if let uid = auth.currentUser?.id, uid != desk.founderId, desk.status == .recruiting {
            VStack(spacing: 0) {
                Divider()
                if myApplication != nil {
                    Button {
                        showApplySheet = true
                    } label: {
                        Label("已申請 · 點擊查看狀態", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColor.secondary.opacity(0.85))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, CardChrome.padding)
                } else {
                    Button {
                        prepareApplySheet(desk)
                        showApplySheet = true
                        HapticFeedback.medium()
                    } label: {
                        Label("申請加入", systemImage: "paperplane.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColor.brandGradient)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(DeskerButtonPressStyle())
                    .deskerButtonShadow()
                    .padding(.horizontal, CardChrome.padding)
                    .padding(.vertical, 12)
                }
                Spacer().frame(height: 0)
            }
            .background(AppColor.background)
        } else {
            EmptyView()
        }
    }

    private func prepareApplySheet(_ desk: Desk) {
        applyError = nil
        applyStatement = ""
        if let first = desk.recruitingRoles.first {
            applySelectedRole = first.title
        } else {
            applySelectedRole = "成員"
        }
    }

    private func applySheet(_ desk: Desk) -> some View {
        NavigationStack {
            Form {
                if let app = myApplication {
                    Section {
                        Text(applicationStatusLabel(app.status))
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("申請狀態")
                    }
                } else {
                    Section {
                        if desk.recruitingRoles.isEmpty {
                            Text(applySelectedRole)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("應徵角色", selection: $applySelectedRole) {
                                ForEach(desk.recruitingRoles, id: \.id) { r in
                                    Text(r.title).tag(r.title)
                                }
                            }
                        }
                        TextField("自我介紹與動機", text: $applyStatement, axis: .vertical)
                            .lineLimit(4...10)
                    } header: {
                        Text("申請內容")
                    }
                    if let applyError {
                        Section {
                            Text(applyError)
                                .foregroundStyle(AppColor.error)
                                .font(.footnote)
                        }
                    }
                    Section {
                        Button {
                            HapticFeedback.medium()
                            Task { await submitApply(desk) }
                        } label: {
                            if applyInFlight {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(AppColor.primary)
                                    Spacer()
                                }
                            } else {
                                Text("送出申請")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(applyInFlight || applyStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("申請加入")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showApplySheet = false }
                }
            }
        }
    }

    private func applicationStatusLabel(_ s: ApplicationStatus) -> String {
        switch s {
        case .pending: return "待審核"
        case .accepted: return "已批准"
        case .declined: return "已拒絕"
        case .hold: return "暫緩"
        }
    }

    private func submitApply(_ desk: Desk) async {
        guard let uid = auth.currentUser?.id else {
            applyError = "請先登入"
            return
        }
        applyInFlight = true
        applyError = nil
        defer { applyInFlight = false }
        let statement = applyStatement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !statement.isEmpty else {
            applyError = "請填寫自我介紹"
            return
        }
        do {
            try await deskRepository.submitApplication(
                deskId: desk.id,
                applicantId: uid,
                selectedRole: applySelectedRole,
                statement: statement
            )
            myApplication = try await deskRepository.fetchMyApplication(deskId: desk.id, applicantId: uid)
            showApplySheet = false
            toast.show(.success, "申請已送出")
            DeskerAnalytics.track(.userApplyToDesk, parameters: ["desk_id": desk.id.uuidString])
            HapticFeedback.success()
        } catch {
            applyError = error.localizedDescription
            HapticFeedback.error()
        }
    }

    private func founderBlock(_ founder: UserProfile) -> some View {
        HStack(alignment: .center, spacing: 16) {
            founderAvatar(avatarUrl: founder.avatarUrl)
            VStack(alignment: .leading, spacing: 8) {
                Text("創辦人")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.gold)
                HStack(spacing: 8) {
                    Text(founder.displayName.isEmpty ? "—" : founder.displayName)
                        .font(.title.bold())
                        .foregroundStyle(AppColor.textPrimary)
                    if founder.verificationBadgeStyle != nil {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.gold)
                    }
                    if let v = founder.verificationBadgeStyle {
                        VerificationBadgeView(style: v)
                    }
                }
            }
            Spacer()
        }
        .padding(CardChrome.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func founderAvatar(avatarUrl: String?) -> some View {
        Group {
            if let s = avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                CachedAsyncImage(url: url, maxPixelDimension: 220) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                    case .empty:
                        ProgressView()
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.gold.opacity(0.55), lineWidth: 2))
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.primary, AppColor.secondary)
                    .overlay(Circle().stroke(AppColor.gold.opacity(0.45), lineWidth: 2))
            }
        }
    }

    private func skillsNeededTagsSection(_ desk: Desk) -> some View {
        let tags = skillTags(for: desk)
        return Group {
            if !tags.isEmpty {
                section(title: "所需技能", icon: "sparkles", color: AppColor.accentOrange) {
                    ColoredDeskTags(tags: tags)
                }
            }
        }
    }

    private func skillTags(for desk: Desk) -> [String] {
        var tags: [String] = []
        for r in desk.recruitingRoles {
            tags.append(r.title)
            if let s = r.skillDescription, !s.isEmpty { tags.append(s) }
        }
        return Array(Set(tags)).sorted()
    }

    /// One block that mirrors the Explore card: expectations line + skills + team + date.
    private func cardParitySummary(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(desk.expectations ?? desk.fundingNeeds ?? "—")
                    .font(.body)
            } icon: {
                Image(systemName: "checklist")
                    .foregroundStyle(AppColor.secondary)
            }
            Label {
                Text(desk.skillsSummary)
                    .font(.body)
            } icon: {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(AppColor.accentOrange)
            }
            HStack {
                Label("\(desk.currentMemberCount)/\(desk.memberLimit) 人", systemImage: "person.2.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.primary)
                Spacer()
                if let created = desk.createdAt {
                    Text(Self.dateFormatter.string(from: created))
                        .font(.caption)
                        .foregroundStyle(AppColor.textTertiary)
                }
            }
        }
        .padding(CardChrome.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func statusText(_ status: DeskStatus) -> some View {
        let (t, c): (String, Color) = {
            switch status {
            case .recruiting: return ("招募中", AppColor.secondary)
            case .full: return ("已滿", AppColor.accentOrange)
            case .archived: return ("已歸檔", .gray)
            }
        }()
        return Text(t)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(c.opacity(0.15))
            .foregroundStyle(c)
            .clipShape(Capsule())
    }

    private func section<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CardChrome.padding)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func metaRow(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("團隊規模：\(desk.currentMemberCount) / \(desk.memberLimit) 人（含創辦人與名額）")
            } icon: {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppColor.primary)
            }
            .font(.subheadline)
            if let created = desk.createdAt {
                Label {
                    Text("建立日期：\(Self.dateFormatter.string(from: created))")
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppColor.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding(CardChrome.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func inviteBlock(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("發送邀請", systemImage: "paperplane.fill")
                .font(.headline)
                .foregroundStyle(AppColor.primary)
            Text("輸入對方的用戶 ID（UUID）。若已邀請過，系統會更新該筆邀請而不會報錯。")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
            TextField("受邀用戶 ID（UUID）", text: $inviteeIdText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .deskerTextFieldNoAutocaps()
            if let inviteMessage {
                Text(inviteMessage)
                    .font(.footnote)
                    .foregroundStyle(inviteMessage.contains("失敗") ? .red : .secondary)
            }
            Button {
                HapticFeedback.medium()
                Task { await sendInvite(desk: desk) }
            } label: {
                if inviteInFlight {
                    ProgressView()
                } else {
                    Text("發送邀請")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(.white)
            .tint(AppColor.primary)
            .disabled(inviteInFlight || inviteeIdText.count < 32)
        }
        .padding(CardChrome.padding)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func sendInvite(desk: Desk) async {
        inviteMessage = nil
        guard let inviter = auth.currentUser?.id,
              let invitee = UUID(uuidString: inviteeIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            inviteMessage = "請輸入有效的 UUID"
            toast.show(.error, "請輸入有效的 UUID")
            HapticFeedback.error()
            return
        }
        inviteInFlight = true
        defer { inviteInFlight = false }
        do {
            if let existing = try await inviteRepository.fetchInvite(deskId: desk.id, inviteeId: invitee),
               existing.status == .pending {
                inviteMessage = "已發送過邀請"
                toast.show(.info, "已發送過邀請")
                HapticFeedback.success()
                return
            }
            try await inviteRepository.sendInvite(
                deskId: desk.id,
                inviterId: inviter,
                inviteeId: invitee
            )
            inviteMessage = "邀請已發送"
            inviteeIdText = ""
            toast.show(.success, "邀請已發送")
            HapticFeedback.success()
        } catch {
            inviteMessage = "發送失敗：\(error.localizedDescription)"
            toast.show(.error, error.localizedDescription)
            HapticFeedback.error()
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        deskNotFound = false
        defer { isLoading = false }
        do {
            let d = try await deskRepository.fetchDesk(id: deskId)
            desk = d
            async let founderFetch: UserProfile? = fetchFounder(id: d.founderId)
            if let uid = auth.currentUser?.id {
                myApplication = try await deskRepository.fetchMyApplication(deskId: d.id, applicantId: uid)
                canAccessGroupChat = (try? await deskRepository.canAccessDeskChat(
                    deskId: d.id,
                    userId: uid,
                    founderId: d.founderId
                )) ?? false
            } else {
                myApplication = nil
                canAccessGroupChat = false
            }
            founder = await founderFetch
        } catch {
            deskDetailLog.error("load desk failed: \(error.localizedDescription, privacy: .public)")
            if let repo = error as? RepositoryError, case .notFound = repo {
                desk = nil
                founder = nil
                deskNotFound = true
                loadError = nil
            } else {
                deskNotFound = false
                loadError = APIErrorMessages.userFacingMessage(for: error)
            }
        }
    }

    private func fetchFounder(id: UUID) async -> UserProfile? {
        try? await userRepository.fetchUser(id: id)
    }

    private func exportDeskStoryCard() async {
        #if os(iOS)
        guard let desk, let founder else { return }
        var founderImage: UIImage?
        if let s = founder.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           let url = URL(string: s) {
            founderImage = await IGCardExportService.loadUIImage(from: url)
        }
        guard let image = IGCardExportService.renderDeskRecruitmentCard(desk: desk, founder: founder, founderAvatar: founderImage) else {
            deskExportBanner = "無法產生圖片"
            return
        }
        let link = PublicLinks.deskURL(deskId: desk.id)
        do {
            try await IGCardExportService.saveToPhotoLibrary(image)
            deskExportBanner = "招募卡已儲存到相簿，可分享"
            deskExportShareItems = [image, link]
            showDeskExportShare = true
            HapticFeedback.success()
        } catch {
            deskExportBanner = "儲存失敗：\(error.localizedDescription)，仍可分享"
            deskExportShareItems = [image, link]
            showDeskExportShare = true
            HapticFeedback.error()
        }
        #endif
    }

    /// Items for `DeskerShareOptionsSheet` IG export (image + URL).
    private func buildDeskIGCardShareItems() async -> [Any]? {
        #if os(iOS)
        guard let desk, let founder else { return nil }
        var founderImage: UIImage?
        if let s = founder.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           let url = URL(string: s) {
            founderImage = await IGCardExportService.loadUIImage(from: url)
        }
        guard let image = IGCardExportService.renderDeskRecruitmentCard(desk: desk, founder: founder, founderAvatar: founderImage) else {
            return nil
        }
        let link = PublicLinks.deskURL(deskId: desk.id)
        return [image, link]
        #else
        return nil
        #endif
    }

    private func shareDeskButton(_ desk: Desk) -> some View {
        Button {
            showDeskShareOptions = true
            HapticFeedback.medium()
        } label: {
            Label("分享 Desk", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(AppColor.brandGradient)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .deskerButtonShadow()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f
    }()
}

private struct DeskDetailHeroGradient: View {
    let deskId: UUID

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        let palettes: [[Color]] = [
            [AppColor.primary, Color(hex: "4A3F8C"), AppColor.secondary],
            [Color(hex: "312E81"), Color(hex: "6D28D9"), Color(hex: "7C3AED")],
            [Color(hex: "134E4A"), Color(hex: "0F766E"), AppColor.teal],
            [Color(hex: "1E3A5F"), Color(hex: "3730A3"), AppColor.secondary],
        ]
        let i = abs(deskId.hashValue) % palettes.count
        return palettes[i]
    }
}

private struct ColoredDeskTags: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), alignment: .leading)], alignment: .leading, spacing: 10) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tagTint(tag).opacity(0.14))
                    .foregroundStyle(tagTint(tag))
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                            .stroke(tagTint(tag).opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }

    private func tagTint(_ tag: String) -> Color {
        let palette: [Color] = [AppColor.primary, AppColor.secondary, AppColor.teal, AppColor.gold]
        let i = abs(tag.hashValue) % palette.count
        return palette[i]
    }
}
