import SwiftUI

/// Full project detail — founder, tags, team, funding, apply / invite.
struct DeskDetailView: View {
    let deskId: UUID

    @EnvironmentObject private var auth: AuthRepository
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
    @State private var showDeskShare = false
    @State private var showDeskReport = false
    @State private var deskExportBanner: String?

    private let deskRepository = DeskRepository()
    private let inviteRepository = InviteRepository()
    private let userRepository = UserRepository()

    private var isFounder: Bool {
        guard let uid = auth.currentUser?.id, let desk else { return false }
        return uid == desk.founderId
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入中…")
            } else if let loadError {
                ContentUnavailableView("無法載入", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if let desk {
                detailScroll(desk)
            } else {
                ContentUnavailableView("找不到專案", systemImage: "folder")
            }
        }
        .navigationTitle("專案詳情")
        .deskerInlineNavigationTitle()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showDeskShare = true
                    HapticFeedback.light()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.primary, AppColor.secondary)
                }
                Button {
                    showDeskReport = true
                    HapticFeedback.light()
                } label: {
                    Image(systemName: "flag")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.accentOrange, AppColor.primary)
                }
                Button {
                    Task { await exportDeskStoryCard() }
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.accentPurple, AppColor.secondary)
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showDeskShare) {
            if let desk {
                ShareSheetView(items: [PublicLinks.deskURL(deskId: desk.id)])
            }
        }
        .sheet(isPresented: $showDeskReport) {
            if let desk {
                ReportSheetView(targetType: .desk, targetId: desk.id) { draft in
                    guard let uid = auth.currentUser?.id else { return }
                    try? await ReportBlockRepository().submitReport(draft, reporterId: uid)
                }
            }
        }
        .sheet(isPresented: $showApplySheet) {
            if let desk {
                applySheet(desk)
            }
        }
    }

    @ViewBuilder
    private func detailScroll(_ desk: Desk) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerBlock(desk)
                if let deskExportBanner {
                    Text(deskExportBanner)
                        .font(.footnote)
                        .foregroundStyle(deskExportBanner.contains("失敗") ? .red : .secondary)
                        .padding(.horizontal)
                }
                if let founder {
                    founderBlock(founder)
                }
                cardParitySummary(desk)
                skillsNeededTagsSection(desk)
                section(title: "簡介", icon: "text.alignleft", color: AppColor.primary) {
                    Text(desk.pitch)
                        .font(.body)
                }
                section(title: "詳細描述", icon: "doc.text", color: AppColor.secondary) {
                    Text(desk.detailedDescription ?? "—")
                        .font(.body)
                }
                section(title: "需求與期望", icon: "checklist", color: AppColor.accentOrange) {
                    Text(desk.expectations ?? "—")
                        .font(.body)
                }
                section(title: "期望資助", icon: "dollarsign.circle", color: AppColor.accentPurple) {
                    Text(desk.fundingNeeds ?? "—")
                        .font(.body)
                }
                section(title: "招募角色與技能", icon: "person.3.fill", color: AppColor.secondary) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(desk.recruitingRoles) { role in
                            HStack(alignment: .top) {
                                Image(systemName: "person.badge.plus")
                                    .foregroundStyle(AppColor.primary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(role.title)
                                        .font(.headline)
                                    Text("名額：\(role.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let s = role.skillDescription {
                                        Text(s)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                        if desk.recruitingRoles.isEmpty {
                            Text(desk.skillsSummary)
                                .font(.body)
                        }
                    }
                }
                section(title: "產業標籤", icon: "tag.fill", color: AppColor.primary) {
                    FlowTags(tags: desk.industryTags)
                }
                metaRow(desk)
                if canAccessGroupChat {
                    NavigationLink {
                        DeskGroupChatView(desk: desk)
                    } label: {
                        Label("群組聊天", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColor.secondaryGroupedSurface, in: RoundedRectangle(cornerRadius: CardChrome.cornerRadius))
                    }
                    .buttonStyle(.plain)
                }
                if isFounder {
                    inviteBlock(desk)
                }
            }
            .padding()
            .padding(.bottom, visitorBottomPadding(desk))
        }
        .background(AppColor.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomActionBar(desk)
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
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColor.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                } else {
                    Button {
                        prepareApplySheet(desk)
                        showApplySheet = true
                    } label: {
                        Label("申請加入", systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
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
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    }
                    Section {
                        Button {
                            Task { await submitApply(desk) }
                        } label: {
                            if applyInFlight {
                                HStack {
                                    Spacer()
                                    ProgressView()
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
                    Button("關閉") { showApplySheet = false }
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
        } catch {
            applyError = error.localizedDescription
        }
    }

    private func founderBlock(_ founder: UserProfile) -> some View {
        HStack(alignment: .center, spacing: 14) {
            founderAvatar(avatarUrl: founder.avatarUrl)
            VStack(alignment: .leading, spacing: 4) {
                Text("創辦人")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(founder.displayName.isEmpty ? "—" : founder.displayName)
                        .font(.headline)
                    if let v = founder.verificationBadgeStyle {
                        VerificationBadgeView(style: v)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.secondaryGroupedSurface)
        )
    }

    private func founderAvatar(avatarUrl: String?) -> some View {
        Group {
            if let s = avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                AsyncImage(url: url) { phase in
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
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(AppColor.primary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.primary, AppColor.secondary)
            }
        }
    }

    private func skillsNeededTagsSection(_ desk: Desk) -> some View {
        let tags = skillTags(for: desk)
        return Group {
            if !tags.isEmpty {
                section(title: "所需技能", icon: "sparkles", color: AppColor.accentOrange) {
                    FlowTags(tags: tags)
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

    private func headerBlock(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(desk.name)
                    .font(.title.bold())
                Spacer()
                statusText(desk.status)
            }
            Text(desk.pitch)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(desk.region) · \(desk.languagePreference.joined(separator: ", "))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.secondaryGroupedSurface)
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
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.secondaryGroupedSurface)
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.secondaryGroupedSurface)
        )
    }

    private func inviteBlock(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("發送邀請", systemImage: "paperplane.fill")
                .font(.headline)
                .foregroundStyle(AppColor.primary)
            Text("輸入對方的用戶 ID（UUID）。若已邀請過，系統會更新該筆邀請而不會報錯。")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Invited user UUID", text: $inviteeIdText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .deskerTextFieldNoAutocaps()
            if let inviteMessage {
                Text(inviteMessage)
                    .font(.footnote)
                    .foregroundStyle(inviteMessage.contains("失敗") ? .red : .secondary)
            }
            Button {
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.secondaryGroupedSurface)
        )
    }

    private func sendInvite(desk: Desk) async {
        inviteMessage = nil
        guard let inviter = auth.currentUser?.id,
              let invitee = UUID(uuidString: inviteeIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            inviteMessage = "請輸入有效的 UUID"
            return
        }
        inviteInFlight = true
        defer { inviteInFlight = false }
        do {
            try await inviteRepository.sendOrUpdateInvite(
                deskId: desk.id,
                inviterId: inviter,
                inviteeId: invitee,
                status: .pending
            )
            inviteMessage = "邀請已送出（或已更新現有邀請）。"
            inviteeIdText = ""
        } catch {
            inviteMessage = "發送失敗：\(error.localizedDescription)"
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
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
            loadError = error.localizedDescription
        }
    }

    private func fetchFounder(id: UUID) async -> UserProfile? {
        try? await userRepository.fetchUser(id: id)
    }

    private func exportDeskStoryCard() async {
        #if os(iOS)
        guard let desk, let founder else { return }
        let name = founder.displayName.isEmpty ? "創辦人" : founder.displayName
        guard let image = IGCardExportService.renderDeskRecruitmentCard(desk: desk, founderName: name) else {
            deskExportBanner = "無法產生圖片"
            return
        }
        do {
            try await IGCardExportService.saveToPhotoLibrary(image)
            deskExportBanner = "招募卡已儲存到相簿"
            HapticFeedback.success()
        } catch {
            deskExportBanner = "儲存失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
        #endif
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f
    }()
}

private struct FlowTags: View {
    let tags: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColor.primary.opacity(0.12))
                    .foregroundStyle(AppColor.primary)
                    .clipShape(Capsule())
            }
        }
    }
}
