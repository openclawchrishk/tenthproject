import SwiftUI

struct MyConnectionsView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var connections: [Connection] = []
    @State private var pending: [ConnectionInvite] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var inviteeUUID = ""
    @State private var banner: String?
    @State private var peerNames: [UUID: String] = [:]
    @State private var peerAvatars: [UUID: String?] = [:]

    private let connectionsRepo = ConnectionRepository()
    private let userRepo = UserRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CardChrome.sectionSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("我的人脈")
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.textPrimary)
                    Text("連接後可私訊 · 點擊頭像開始對話")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.horizontal, CardChrome.padding)

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(AppColor.primary)
                        Text("載入中…")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else if let errorText {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "載入失敗",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorText).foregroundStyle(AppColor.error)
                        )
                        Button("重試") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(AppColor.primary)
                    }
                    .padding(.top, 8)
                } else {
                    if !connections.isEmpty {
                        connectionAvatarGrid
                    }

                    inviteSection

                    pendingSection

                    connectedListSection
                }
            }
            .padding(.bottom, 28)
        }
        .background(AppColor.background.ignoresSafeArea())
        .task { await load() }
        .refreshable { await load() }
    }

    private var connectionAvatarGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("已連接")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.primary)
                .padding(.horizontal, CardChrome.padding)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: 16)],
                spacing: 16
            ) {
                ForEach(connections) { c in
                    if let uid = auth.currentUser?.id {
                        let other = c.otherUser(than: uid)
                        NavigationLink {
                            DMChatView(peerId: other, peerDisplayName: peerNames[other] ?? "聯絡人")
                        } label: {
                            VStack(spacing: 8) {
                                peerAvatar(userId: other, name: peerNames[other] ?? "?", size: 64)
                                Text(peerNames[other] ?? "用戶")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppColor.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, CardChrome.padding)
        }
    }

    private func peerAvatar(userId: UUID, name: String, size: CGFloat = 64) -> some View {
        let urlString = peerAvatars[userId] ?? nil
        return Group {
            if let s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        initialsCircle(name, size: size)
                    @unknown default:
                        initialsCircle(name, size: size)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.primary.opacity(0.2), lineWidth: 2))
            } else {
                initialsCircle(name, size: size)
            }
        }
    }

    private func initialsCircle(_ name: String, size: CGFloat) -> some View {
        let initial = name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "?"
        return ZStack {
            Circle()
                .fill(AppColor.brandGradient)
                .frame(width: size, height: size)
            Text(initial)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().stroke(AppColor.gold.opacity(0.35), lineWidth: 2))
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("發送連接邀請", systemImage: "paperplane.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.secondary)
            TextField("使用者 UUID", text: $inviteeUUID)
                .deskerTextFieldNoAutocaps()
                .autocorrectionDisabled()
                .padding(14)
                .background(AppColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
            Button {
                Task { await sendInvite() }
            } label: {
                Text("送出邀請")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(inviteeUUID.count < 32)
            if let banner {
                Text(banner)
                    .font(.footnote)
                    .foregroundStyle(banner.contains("失敗") ? AppColor.error : AppColor.textSecondary)
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
        .padding(.horizontal, CardChrome.padding)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("待處理邀請", systemImage: "clock.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.gold)
            if pending.isEmpty {
                Text("沒有待處理的邀請")
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                ForEach(pending) { inv in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("來自 \(peerNames[inv.fromUserId] ?? "用戶")")
                                .font(.body.weight(.medium))
                            Text(inv.id.uuidString)
                                .font(.caption2)
                                .foregroundStyle(AppColor.textTertiary)
                        }
                        Spacer()
                        Button("拒絕") {
                            Task { await decline(inv) }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColor.error.opacity(0.12))
                        .foregroundStyle(AppColor.error)
                        .clipShape(Capsule())
                        Button("接受") {
                            Task { await accept(inv) }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColor.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
        .padding(.horizontal, CardChrome.padding)
    }

    private var connectedListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("聯絡人列表", systemImage: "person.2.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColor.primary)
            if connections.isEmpty {
                Text("你還沒有建立人脈，試試在探索發送連接邀請")
                    .font(.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(connections) { c in
                    if let uid = auth.currentUser?.id {
                        let other = c.otherUser(than: uid)
                        NavigationLink {
                            DMChatView(peerId: other, peerDisplayName: peerNames[other] ?? "聯絡人")
                        } label: {
                            HStack(spacing: 14) {
                                peerAvatar(userId: other, name: peerNames[other] ?? "?", size: 48)
                                Text(peerNames[other] ?? "用戶")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                Menu {
                                    Button(role: .destructive) {
                                        Task { await remove(c) }
                                    } label: {
                                        Label("移除連接", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .padding(CardChrome.padding)
        .deskerElevatedCard()
        .padding(.horizontal, CardChrome.padding)
    }
}

private extension MyConnectionsView {
    func load() async {
        guard let uid = auth.currentUser?.id else {
            errorText = "請先登入"
            isLoading = false
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            connections = try await connectionsRepo.fetchConnections(for: uid)
            pending = try await connectionsRepo.fetchPendingInvites(for: uid)
            var names: [UUID: String] = [:]
            var avatars: [UUID: String?] = [:]
            for c in connections {
                let other = c.otherUser(than: uid)
                if let u = try? await userRepo.fetchUser(id: other) {
                    names[other] = u.displayName.isEmpty ? "用戶" : u.displayName
                    avatars[other] = u.avatarUrl
                }
            }
            for inv in pending {
                if names[inv.fromUserId] == nil, let u = try? await userRepo.fetchUser(id: inv.fromUserId) {
                    names[inv.fromUserId] = u.displayName.isEmpty ? "用戶" : u.displayName
                    avatars[inv.fromUserId] = u.avatarUrl
                }
            }
            peerNames = names
            peerAvatars = avatars
        } catch {
            errorText = error.localizedDescription
        }
    }

    func sendInvite() async {
        guard let from = auth.currentUser?.id,
              let to = UUID(uuidString: inviteeUUID.trimmingCharacters(in: .whitespacesAndNewlines)),
              to != from
        else {
            banner = "請輸入有效的 UUID"
            return
        }
        banner = nil
        do {
            try await connectionsRepo.sendConnectionInvite(from: from, to: to)
            inviteeUUID = ""
            banner = "邀請已送出"
            HapticFeedback.success()
            await load()
        } catch {
            banner = "失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
    }

    func accept(_ inv: ConnectionInvite) async {
        guard let uid = auth.currentUser?.id else { return }
        do {
            try await connectionsRepo.acceptConnectionInvite(inviteId: inv.id, currentUserId: uid)
            HapticFeedback.success()
            await load()
        } catch {
            banner = "接受失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
    }

    func decline(_ inv: ConnectionInvite) async {
        guard let uid = auth.currentUser?.id else { return }
        do {
            try await connectionsRepo.declineConnectionInvite(inviteId: inv.id, currentUserId: uid)
            HapticFeedback.success()
            await load()
        } catch {
            banner = "拒絕失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
    }

    func remove(_ c: Connection) async {
        guard let uid = auth.currentUser?.id else { return }
        let other = c.otherUser(than: uid)
        do {
            try await connectionsRepo.removeConnection(userId: uid, peerId: other)
            HapticFeedback.success()
            await load()
        } catch {
            errorText = error.localizedDescription
            HapticFeedback.error()
        }
    }
}
