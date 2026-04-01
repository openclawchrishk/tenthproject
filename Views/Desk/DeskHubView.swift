import SwiftUI

/// Founder's hub: **own desks** and **incoming applications** with approve / reject.
struct DeskHubView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var tabRouter: MainTabRouter
    @State private var deskNavPath = NavigationPath()
    @State private var myDesks: [Desk] = []
    @State private var applications: [DeskApplicationItem] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var processingId: UUID?
    @State private var showCreateDesk = false

    private let deskRepository = DeskRepository()

    var body: some View {
        NavigationStack(path: $deskNavPath) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                AppHeaderView(
                    title: "Desk",
                    subtitle: "我創建的專案與申請管理"
                )
                if !DeskerUXPreferences.tipDeskDismissed {
                    deskFirstVisitTip
                        .padding(.horizontal, CardChrome.padding)
                        .padding(.bottom, 8)
                }
                content
                }
                .background(AppColor.background.ignoresSafeArea())
                .deskerHiddenNavigationBar()

                Button {
                    showCreateDesk = true
                    HapticFeedback.light()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.primary, AppColor.secondary)
                        .shadow(color: CardChrome.buttonShadowColor, radius: 4, x: 0, y: 2)
                }
                .accessibilityLabel("建立 Desk")
                .padding(.trailing, CardChrome.padding)
                .padding(.top, 12)

                if isLoading && (!myDesks.isEmpty || !applications.isEmpty) {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(AppColor.primary)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                DeskDetailView(deskId: id)
            }
        }
        .onChange(of: tabRouter.pendingOpenDeskId) { _, id in
            guard let id else { return }
            deskNavPath.append(id)
            tabRouter.pendingOpenDeskId = nil
        }
        .sheet(isPresented: $showCreateDesk, onDismiss: {
            Task { await reload() }
        }) {
            CreateDeskView()
                .environmentObject(auth)
                .environmentObject(toast)
                .deskerSheetSpringContent()
        }
        .task { await reload() }
        .refreshable {
            #if os(iOS)
            HapticFeedback.light()
            #endif
            await reload()
        }
    }

    private var deskFirstVisitTip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "tray.full.fill")
                .foregroundStyle(AppColor.secondary)
            Text("有新申請時 Desk 分頁會顯示紅點；喺下方「收到的申請」可以一次過審批。")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(3)
                .frame(maxWidth: 560, alignment: .leading)
            Button {
                DeskerUXPreferences.tipDeskDismissed = true
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
                .fill(AppColor.secondary.opacity(0.1))
        )
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && myDesks.isEmpty && applications.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppColor.primary)
                Text("載入中...")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.top, 48)
        } else if let err = errorText, myDesks.isEmpty, applications.isEmpty {
            DeskerErrorStateView(message: err, onRetry: {
                Task { await reload() }
            }, detail: nil)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CardChrome.sectionSpacing) {
                    if let errorText, (!myDesks.isEmpty || !applications.isEmpty) {
                        VStack(spacing: 10) {
                            Text(errorText)
                                .font(.subheadline)
                                .foregroundStyle(AppColor.error)
                                .multilineTextAlignment(.center)
                            Button("重試") {
                                Task { await reload() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppColor.primary)
                        }
                        .padding(CardChrome.padding)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                .fill(AppColor.error.opacity(0.08))
                        )
                    }
                    sectionTitle("我創建的專案", icon: "folder.fill", tint: AppColor.primary)

                    if myDesks.isEmpty {
                        deskProjectsEmpty
                    } else {
                        ForEach(myDesks) { desk in
                            NavigationLink {
                                DeskDetailView(deskId: desk.id)
                            } label: {
                                deskFounderCard(desk)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    sectionTitle("收到的申請", icon: "tray.full.fill", tint: AppColor.secondary)

                    if applications.isEmpty {
                        applicationsEmpty
                    } else {
                        ForEach(applications) { item in
                            applicationCard(item)
                        }
                    }
                }
                .padding(.horizontal, CardChrome.padding)
                .padding(.bottom, 28)
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(tint)
            .padding(.top, 8)
    }

    private var deskProjectsEmpty: some View {
        VStack(spacing: 18) {
            Image(systemName: "briefcase")
                .font(.system(size: 52))
                .foregroundStyle(AppColor.textSecondary)
            Text("你仲未建立Desk")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                HapticFeedback.medium()
                showCreateDesk = true
            } label: {
                Text("建立Desk")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColor.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(DeskerCardPressStyle())
            .deskerButtonShadow()
        }
        .frame(maxWidth: .infinity)
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }

    private var applicationsEmpty: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.textSecondary)
            Text("仲未有申請")
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }

    private func deskFounderCard(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(desk.name.deskerTruncated(maxLength: 20))
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                deskStatusPill(desk.status)
            }
            Text(desk.pitch.deskerTruncated(maxLength: 100))
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(3)
            HStack(spacing: 14) {
                Label("\(desk.currentMemberCount)/\(desk.memberLimit) 人", systemImage: "person.2.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.primary)
                if !desk.skillsSummary.isEmpty {
                    Text(desk.skillsSummary)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }

    private func deskStatusPill(_ status: DeskStatus) -> some View {
        let (t, c): (String, Color) = {
            switch status {
            case .recruiting: return ("招募中", AppColor.primary)
            case .full: return ("已滿", AppColor.gold)
            case .archived: return ("已歸檔", AppColor.textSecondary)
            }
        }()
        return Text(t)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(c.opacity(0.18))
            .foregroundStyle(c)
            .clipShape(Capsule())
    }

    private func applicationCard(_ item: DeskApplicationItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                applicantAvatar(url: item.applicantAvatarUrl)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.deskName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColor.secondary)
                        Spacer()
                        Text(statusLabel(item.application.status))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(statusColor(item.application.status).opacity(0.15))
                            .foregroundStyle(statusColor(item.application.status))
                            .clipShape(Capsule())
                    }
                    Text(item.applicantDisplayName)
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("應徵角色：\(item.application.selectedRole)")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                    Text(item.application.statement)
                        .font(.body)
                        .foregroundStyle(AppColor.textSecondary)
                    if !item.applicantSkills.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(item.applicantSkills.prefix(8), id: \.self) { sk in
                                    Text(sk)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppColor.teal.opacity(0.14))
                                        .foregroundStyle(AppColor.primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }

            if item.application.status == .pending {
                HStack(spacing: 12) {
                    Button {
                        Task { await setStatus(item, to: .accepted) }
                    } label: {
                        Label("批准", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [AppColor.success, AppColor.gold.opacity(0.92)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(processingId != nil)

                    Button {
                        Task { await setStatus(item, to: .declined) }
                    } label: {
                        Label("拒絕", systemImage: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColor.error.opacity(0.12))
                            .foregroundStyle(AppColor.error)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.error.opacity(0.45), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(processingId != nil)
                }
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
        .opacity(processingId == item.application.id ? 0.5 : 1)
    }

    private func applicantAvatar(url: String?) -> some View {
        Group {
            if let s = url?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let u = URL(string: s) {
                CachedAsyncImage(url: u, maxPixelDimension: 200) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderPerson
                    case .empty:
                        ProgressView()
                            .tint(AppColor.primary)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.primary.opacity(0.25), lineWidth: 1.5))
            } else {
                placeholderPerson
            }
        }
    }

    private var placeholderPerson: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 52))
            .symbolRenderingMode(.palette)
            .foregroundStyle(AppColor.primary, AppColor.secondary)
    }

    private func statusLabel(_ s: ApplicationStatus) -> String {
        switch s {
        case .pending: return "待審核"
        case .accepted: return "已批准"
        case .declined: return "已拒絕"
        case .hold: return "暫緩"
        }
    }

    private func statusColor(_ s: ApplicationStatus) -> Color {
        switch s {
        case .pending: return AppColor.gold
        case .accepted: return AppColor.success
        case .declined: return AppColor.error
        case .hold: return AppColor.textSecondary
        }
    }

    private func setStatus(_ item: DeskApplicationItem, to status: ApplicationStatus) async {
        guard let founderId = auth.currentUser?.id else {
            errorText = "請先登入"
            toast.show(.error, "請先登入")
            return
        }
        processingId = item.application.id
        defer { processingId = nil }
        do {
            if status == .accepted {
                try await deskRepository.approveApplication(applicationId: item.application.id, actingFounderId: founderId)
                toast.show(.success, "已批准，成員已加入")
            } else {
                try await deskRepository.updateApplicationStatus(applicationId: item.application.id, status: status)
                toast.show(.info, status == .declined ? "已拒絕申請" : "申請狀態已更新")
            }
            HapticFeedback.success()
            await reload()
        } catch {
            let msg = APIErrorMessages.userFacingMessage(for: error)
            errorText = msg
            toast.show(.error, msg)
            HapticFeedback.error()
        }
    }

    private func reload() async {
        guard let uid = auth.currentUser?.id else {
            errorText = "請先登入"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            async let d = deskRepository.fetchDesksForFounder(founderId: uid)
            async let a = deskRepository.fetchApplicationsForFounder(founderId: uid)
            myDesks = try await d
            applications = try await a
        } catch {
            let msg = APIErrorMessages.userFacingMessage(for: error)
            errorText = msg
            if !myDesks.isEmpty || !applications.isEmpty {
                toast.show(.info, "更新失敗，顯示上次資料")
            }
        }
    }
}
