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

    private let connectionsRepo = ConnectionRepository()
    private let userRepo = UserRepository()

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderView(title: "我的人脈", subtitle: "連接後可私訊")
            if isLoading {
                ProgressView().padding(.top, 32)
            } else if let errorText {
                ContentUnavailableView("載入失敗", systemImage: "exclamationmark.triangle", description: Text(errorText))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("重試") { Task { await load() } }
                        }
                    }
            } else {
                List {
                    Section("發送連接邀請（對方 UUID）") {
                        TextField("使用者 UUID", text: $inviteeUUID)
                            .deskerTextFieldNoAutocaps()
                            .autocorrectionDisabled()
                        Button("送出邀請") {
                            Task { await sendInvite() }
                        }
                        .disabled(inviteeUUID.count < 32)
                        if let banner {
                            Text(banner)
                                .font(.footnote)
                                .foregroundStyle(banner.contains("失敗") ? .red : .secondary)
                        }
                    }
                    Section("待處理邀請") {
                        if pending.isEmpty {
                            Text("沒有待處理的邀請").foregroundStyle(.secondary)
                        } else {
                            ForEach(pending) { inv in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("來自 \(peerNames[inv.fromUserId] ?? "用戶")")
                                        Text(inv.id.uuidString)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Button("接受") {
                                        Task { await accept(inv) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppColor.secondary)
                                }
                            }
                        }
                    }
                    Section("已連接") {
                        if connections.isEmpty {
                            Text("尚無連接，發送邀請或接受邀請以建立人脈。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(connections) { c in
                                let other = c.otherUser(than: auth.currentUser?.id ?? c.userAId)
                                NavigationLink {
                                    DMChatView(peerId: other, peerDisplayName: peerNames[other] ?? "聯絡人")
                                } label: {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(AppColor.primary, AppColor.secondary)
                                        Text(peerNames[other] ?? "用戶")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        Task { await remove(c) }
                                    } label: {
                                        Label("移除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .deskerInsetGroupedListStyle()
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .task { await load() }
        .refreshable { await load() }
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
            for c in connections {
                let other = c.otherUser(than: uid)
                if let u = try? await userRepo.fetchUser(id: other) {
                    names[other] = u.displayName.isEmpty ? "用戶" : u.displayName
                }
            }
            for inv in pending {
                if names[inv.fromUserId] == nil, let u = try? await userRepo.fetchUser(id: inv.fromUserId) {
                    names[inv.fromUserId] = u.displayName.isEmpty ? "用戶" : u.displayName
                }
            }
            peerNames = names
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
