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
    @State private var processingInviteId: UUID?

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

                inboxSegmentPicker
                    .padding(.horizontal, CardChrome.padding)
                    .padding(.bottom, 12)

                if isLoading && (segment == 0 || segment == 2) {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(AppColor.primary)
                        Text("載入中...")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(.top, 40)
                } else if let errorText, segment == 0 || segment == 2 {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColor.error)
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.error)
                            .multilineTextAlignment(.center)
                        Button("重試") {
                            Task { await loadAll() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.primary)
                    }
                    .padding(CardChrome.padding)
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

    private var inboxSegmentPicker: some View {
        Picker("", selection: $segment) {
            Text("私訊 (\(messages.count))").tag(0)
            Text("通知").tag(1)
            Text("Desk (\(pendingInviteCount))").tag(2)
            Text("人脈").tag(3)
        }
        .pickerStyle(.segmented)
        .tint(AppColor.primary)
    }

    private var pendingInviteCount: Int {
        guard let uid = auth.currentUser?.id else { return 0 }
        return invites.filter { $0.status == .pending && $0.inviteeId == uid }.count
    }

    @ViewBuilder
    private var dmSegment: some View {
        if messages.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColor.textTertiary)
                Text("暫時沒有訊息")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("連接創辦人或回覆邀請後，對話會顯示於此")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(CardChrome.padding)
            .padding(.top, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { item in
                        if let uid = auth.currentUser?.id {
                            let peerId = item.conversation.otherUser(than: uid)
                            NavigationLink {
                                DMChatView(peerId: peerId, peerDisplayName: item.peerDisplayName)
                            } label: {
                                dmRow(item, currentUserId: uid)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, CardChrome.padding)
                .padding(.bottom, 24)
            }
        }
    }

    private func dmRow(_ item: MessageListItem, currentUserId: UUID) -> some View {
        let unread = item.message.senderId != currentUserId
        return HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                dmAvatar(for: item.peerDisplayName)
                if unread {
                    Circle()
                        .fill(AppColor.primary)
                        .frame(width: 10, height: 10)
                        .offset(x: 4, y: -4)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.peerDisplayName)
                        .font(unread ? .headline.weight(.bold) : .headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    if let d = item.message.createdAt {
                        Text(Self.shortDate.string(from: d))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(item.message.body)
                    .font(.subheadline)
                    .foregroundStyle(unread ? AppColor.textPrimary : AppColor.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(CardChrome.padding)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func dmAvatar(for name: String) -> some View {
        let initial = name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "?"
        return ZStack {
            Circle()
                .fill(AppColor.brandGradient)
                .frame(width: 52, height: 52)
            Text(initial)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private var inviteList: some View {
        Group {
            if invites.isEmpty {
                ContentUnavailableView("沒有邀請", systemImage: "envelope.open", description: Text("發送或收到的 Desk 邀請會顯示於此"))
                    .padding(.top, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(invites) { inv in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(deskNames[inv.deskId] ?? "Desk")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppColor.textPrimary)
                                    Spacer()
                                    Text(statusLabel(inv.status))
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppColor.primary.opacity(0.12))
                                        .foregroundStyle(AppColor.primary)
                                        .clipShape(Capsule())
                                }
                                Text(inv.inviteeId == auth.currentUser?.id ? "你收到邀請" : "你發出的邀請")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.textSecondary)
                                if inv.status == .pending,
                                   inv.inviteeId == auth.currentUser?.id,
                                   let uid = auth.currentUser?.id {
                                    HStack(spacing: 12) {
                                        Button {
                                            Task { await respondToDeskInvite(inv, as: uid, accept: true) }
                                        } label: {
                                            Text("接受")
                                                .font(.subheadline.weight(.semibold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(AppColor.brandGradient)
                                                .foregroundStyle(.white)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(processingInviteId != nil)

                                        Button {
                                            Task { await respondToDeskInvite(inv, as: uid, accept: false) }
                                        } label: {
                                            Text("拒絕")
                                                .font(.subheadline.weight(.semibold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(AppColor.error.opacity(0.12))
                                                .foregroundStyle(AppColor.error)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(processingInviteId != nil)
                                    }
                                    .opacity(processingInviteId == inv.id ? 0.5 : 1)
                                }
                            }
                            .padding(CardChrome.padding)
                            .background(
                                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                                    .fill(AppColor.cardBackground)
                                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                            )
                        }
                    }
                    .padding(.horizontal, CardChrome.padding)
                    .padding(.bottom, 24)
                }
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

    private func respondToDeskInvite(_ inv: Invite, as uid: UUID, accept: Bool) async {
        processingInviteId = inv.id
        defer { processingInviteId = nil }
        do {
            if accept {
                try await invitesRepo.acceptInvite(inviteId: inv.id, actingUserId: uid)
            } else {
                try await invitesRepo.declineInvite(inviteId: inv.id, actingUserId: uid)
            }
            await loadAll()
        } catch {
            errorText = error.localizedDescription
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
