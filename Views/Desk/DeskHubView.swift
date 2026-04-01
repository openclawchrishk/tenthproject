import SwiftUI

/// Founder's hub: **own desks** and **incoming applications** with approve / reject.
struct DeskHubView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @State private var myDesks: [Desk] = []
    @State private var applications: [DeskApplicationItem] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var processingId: UUID?
    @State private var showCreateDesk = false

    private let deskRepository = DeskRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "Desk",
                    subtitle: "我創建的專案與申請管理"
                )
                content
            }
            .background(AppColor.background.ignoresSafeArea())
            .deskerHiddenNavigationBar()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateDesk = true
                    HapticFeedback.light()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.primary, AppColor.secondary)
                }
            }
        }
        .sheet(isPresented: $showCreateDesk, onDismiss: {
            Task { await reload() }
        }) {
            CreateDeskView()
                .environmentObject(auth)
                .environmentObject(toast)
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && myDesks.isEmpty && applications.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppColor.secondary)
                Text("載入中...")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.top, 48)
        } else if let errorText {
            VStack(spacing: 16) {
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
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: CardChrome.sectionSpacing) {
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
            .font(.title3.weight(.bold))
            .foregroundStyle(tint)
            .padding(.top, 8)
    }

    private var deskProjectsEmpty: some View {
        VStack(spacing: 18) {
            Image(systemName: "briefcase")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.textSecondary)
            Text("你仲未建立Desk")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                HapticFeedback.medium()
                showCreateDesk = true
            } label: {
                Text("建立第一個Desk")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
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
                .font(.system(size: 36))
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
                Text(desk.name)
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                deskStatusPill(desk.status)
            }
            Text(desk.pitch)
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
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.textPrimary)
                    Text("應徵角色：\(item.application.selectedRole)")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                    Text(item.application.statement)
                        .font(.body)
                        .foregroundStyle(AppColor.textSecondary)
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
                AsyncImage(url: u) { phase in
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
                    @unknown default:
                        placeholderPerson
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
        processingId = item.application.id
        defer { processingId = nil }
        do {
            try await deskRepository.updateApplicationStatus(applicationId: item.application.id, status: status)
            HapticFeedback.success()
            await reload()
        } catch {
            errorText = error.localizedDescription
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
            errorText = error.localizedDescription
        }
    }
}
