import SwiftUI

/// 訊息中心：私訊、通知、Desk 邀請、人脈。
struct MessagesInboxView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var segment = 0
    @State private var messages: [MessageListItem] = []
    @State private var invites: [Invite] = []
    @State private var deskNames: [UUID: String] = [:]
    @State private var isLoading = false
    @State private var errorText: String?

    private let messagesRepo = MessageRepository()
    private let invitesRepo = InviteRepository()
    private let desksRepo = DeskRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "訊息",
                    subtitle: "私訊、通知與邀請"
                )
                Picker("", selection: $segment) {
                    Text("私訊").tag(0)
                    Text("通知").tag(1)
                    Text("Desk 邀請").tag(2)
                    Text("人脈").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if isLoading && segment != 1 && segment != 3 {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("載入中…")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(.top, 32)
                } else if let errorText, segment == 0 || segment == 2 {
                    VStack(spacing: 12) {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(AppColor.error)
                            .multilineTextAlignment(.center)
                        Button("重試") {
                            Task { await loadAll() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.primary)
                    }
                    .padding()
                } else {
                    switch segment {
                    case 0:
                        dmSegment
                    case 1:
                        NotificationsView()
                    case 2:
                        inviteList
                    case 3:
                        MyConnectionsView()
                    default:
                        EmptyView()
                    }
                }
                Spacer(minLength: 0)
            }
            .background(AppColor.background.ignoresSafeArea())
            .deskerHiddenNavigationBar()
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
    }

    @ViewBuilder
    private var dmSegment: some View {
        if messages.isEmpty {
            ContentUnavailableView(
                "暫時沒有訊息",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("與已連接的用戶開始對話")
            )
            .padding(.top, 24)
        } else {
            List(messages) { item in
                if let uid = auth.currentUser?.id {
                    let peerId = item.conversation.otherUser(than: uid)
                    NavigationLink {
                        DMChatView(peerId: peerId, peerDisplayName: item.peerDisplayName)
                    } label: {
                        dmRow(item)
                    }
                }
            }
            .deskerInsetGroupedListStyle()
        }
    }

    private func dmRow(_ item: MessageListItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.primary, AppColor.secondary)
                Text(item.peerDisplayName)
                    .font(.headline)
                Spacer()
                if let d = item.message.createdAt {
                    Text(Self.shortDate.string(from: d))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Text(item.message.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }

    private var inviteList: some View {
        Group {
            if invites.isEmpty {
                ContentUnavailableView("沒有邀請", systemImage: "envelope.open", description: Text("發送或收到的 Desk 邀請會顯示於此"))
                    .padding(.top, 24)
            } else {
                List(invites) { inv in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(deskNames[inv.deskId] ?? "Desk")
                                .font(.headline)
                            Spacer()
                            Text(statusLabel(inv.status))
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColor.primary.opacity(0.12))
                                .foregroundStyle(AppColor.primary)
                                .clipShape(Capsule())
                        }
                        Text(inv.inviteeId == auth.currentUser?.id ? "你收到邀請" : "你發出的邀請")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .deskerInsetGroupedListStyle()
            }
        }
    }

    private func statusLabel(_ s: InviteStatus) -> String {
        switch s {
        case .pending: return "待回覆"
        case .accepted: return "已接受"
        case .declined: return "已拒絕"
        }
    }

    private func loadAll() async {
        guard let uid = auth.currentUser?.id else {
            errorText = "請先登入"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        var messagesError: String?
        var invitesError: String?

        do {
            messages = try await messagesRepo.fetchRecentMessagesPreview(for: uid)
        } catch {
            messages = []
            messagesError = error.localizedDescription
        }

        do {
            let i = try await invitesRepo.fetchInvitesForUser(userId: uid)
            invites = i
            var names: [UUID: String] = [:]
            let deskIds = Array(Set(i.map(\.deskId)))
            for did in deskIds {
                if let desk = try? await desksRepo.fetchDesk(id: did) {
                    names[did] = desk.name
                }
            }
            deskNames = names
        } catch {
            invites = []
            deskNames = [:]
            invitesError = error.localizedDescription
        }

        if let a = messagesError, let b = invitesError {
            errorText = "對話：\(a)\n邀請：\(b)"
        } else if let a = messagesError {
            errorText = "對話載入失敗：\(a)"
        } else if let b = invitesError {
            errorText = "邀請載入失敗：\(b)"
        }
    }

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f
    }()
}
