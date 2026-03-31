import SwiftUI
import UIKit

/// Full project detail — mirrors Explore card fields and adds long-form sections.
struct DeskDetailView: View {
    let deskId: UUID

    @EnvironmentObject private var auth: AuthRepository
    @State private var desk: Desk?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var inviteeIdText = ""
    @State private var inviteMessage: String?
    @State private var inviteInFlight = false

    private let deskRepository = DeskRepository()
    private let inviteRepository = InviteRepository()

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
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func detailScroll(_ desk: Desk) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerBlock(desk)
                cardParitySummary(desk)
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
                section(title: "資金 / 資源需求", icon: "dollarsign.circle", color: AppColor.accentPurple) {
                    Text(desk.fundingNeeds ?? "—")
                        .font(.body)
                }
                section(title: "技能與招募角色", icon: "person.3.fill", color: AppColor.secondary) {
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
                if auth.currentUser?.id == desk.founderId {
                    inviteBlock(desk)
                }
            }
            .padding()
        }
        .background(AppColor.background.ignoresSafeArea())
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
                .fill(Color(UIColor.secondarySystemGroupedBackground))
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
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private func metaRow(_ desk: Desk) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("團隊規模：\(desk.currentMemberCount) / \(desk.memberLimit) 人")
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
                .fill(Color(UIColor.secondarySystemGroupedBackground))
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
                .textInputAutocapitalization(.never)
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
            .tint(AppColor.primary)
            .disabled(inviteInFlight || inviteeIdText.count < 32)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
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
            desk = try await deskRepository.fetchDesk(id: deskId)
        } catch {
            loadError = error.localizedDescription
        }
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
