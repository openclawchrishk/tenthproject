import SwiftUI

/// Founder's hub: **own desks** and **incoming applications** with approve / reject.
struct DeskHubView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var myDesks: [Desk] = []
    @State private var applications: [DeskApplicationItem] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var processingId: UUID?

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
        .task { await reload() }
        .refreshable { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && myDesks.isEmpty && applications.isEmpty {
            ProgressView()
                .padding(.top, 48)
        } else if let errorText {
            Text(errorText)
                .foregroundStyle(.red)
                .padding()
        } else {
            List {
                Section {
                    if myDesks.isEmpty {
                        Text("你尚未建立任何 Desk，或資料仍在載入。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(myDesks) { desk in
                            NavigationLink {
                                DeskDetailView(deskId: desk.id)
                            } label: {
                                deskFounderRow(desk)
                            }
                        }
                    }
                } header: {
                    Label("我創建的專案", systemImage: "folder.fill")
                        .foregroundStyle(AppColor.primary)
                }

                Section {
                    if applications.isEmpty {
                        Text("目前沒有待處理的申請。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(applications) { item in
                            applicationRow(item)
                        }
                    }
                } header: {
                    Label("收到的申請", systemImage: "tray.full.fill")
                        .foregroundStyle(AppColor.secondary)
                }
            }
            .deskerInsetGroupedListStyle()
        }
    }

    private func deskFounderRow(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(desk.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                deskStatusPill(desk.status)
            }
            Text(desk.pitch)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Label("\(desk.currentMemberCount)/\(desk.memberLimit) 人", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.primary)
                if !desk.skillsSummary.isEmpty {
                    Text(desk.skillsSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func deskStatusPill(_ status: DeskStatus) -> some View {
        let (t, c): (String, Color) = {
            switch status {
            case .recruiting: return ("招募中", AppColor.secondary)
            case .full: return ("已滿", AppColor.accentOrange)
            case .archived: return ("已歸檔", .gray)
            }
        }()
        return Text(t)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(c.opacity(0.15))
            .foregroundStyle(c)
            .clipShape(Capsule())
    }

    private func applicationRow(_ item: DeskApplicationItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppColor.primary, AppColor.secondary)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(item.deskName)
                        .font(.caption.bold())
                        .foregroundStyle(AppColor.secondary)
                    Spacer()
                    Text(statusLabel(item.application.status))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(item.application.status).opacity(0.15))
                        .foregroundStyle(statusColor(item.application.status))
                        .clipShape(Capsule())
                }
                Text(item.applicantDisplayName)
                    .font(.headline)
                Text("應徵角色：\(item.application.selectedRole)")
                    .font(.subheadline)
                Text(item.application.statement)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if item.application.status == .pending {
                    HStack(spacing: 12) {
                        Button {
                            Task { await setStatus(item, to: .accepted) }
                        } label: {
                            Label("批准", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.secondary)
                        .disabled(processingId != nil)

                        Button {
                            Task { await setStatus(item, to: .declined) }
                        } label: {
                            Label("拒絕", systemImage: "xmark.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(processingId != nil)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 6)
        .opacity(processingId == item.application.id ? 0.5 : 1)
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
        case .pending: return AppColor.accentOrange
        case .accepted: return AppColor.secondary
        case .declined: return .red
        case .hold: return .gray
        }
    }

    private func setStatus(_ item: DeskApplicationItem, to status: ApplicationStatus) async {
        processingId = item.application.id
        defer { processingId = nil }
        do {
            try await deskRepository.updateApplicationStatus(applicationId: item.application.id, status: status)
            await reload()
        } catch {
            errorText = error.localizedDescription
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
