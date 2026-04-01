import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @State private var items: [AppNotification] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var realtimeTask: Task<Void, Never>?
    @State private var markAllInFlight = false
    @State private var connectionInviteDetailId: UUID?

    private let repo = NotificationRepository()

    private var groupedSections: [(day: Date, notifications: [AppNotification])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: items) { n -> Date in
            cal.startOfDay(for: n.createdAt ?? .distantPast)
        }
        return grouped
            .map { (day: $0.key, notifications: $0.value.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(AppColor.primary)
                    Text("載入中...")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.top, 24)
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
            } else if items.isEmpty {
                ContentUnavailableView(
                    "暫時沒有通知",
                    systemImage: "bell.slash",
                    description: Text("新邀請、申請與訊息會顯示於此")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CardChrome.sectionSpacing) {
                        ForEach(groupedSections, id: \.day) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(sectionHeader(section.day))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColor.textSecondary)
                                    .padding(.horizontal, 4)

                                ForEach(section.notifications, id: \.id) { n in
                                    notificationCard(n)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            Task { await onNotificationTap(n) }
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, CardChrome.padding)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !items.isEmpty, items.contains(where: { !$0.read }) {
                    Button {
                        Task { await markAllRead() }
                    } label: {
                        if markAllInFlight {
                            ProgressView()
                                .tint(AppColor.primary)
                        } else {
                            Text("全部已讀")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.primary)
                        }
                    }
                    .disabled(markAllInFlight)
                }
            }
        }
        .task {
            await load()
            startRealtime()
        }
        .onDisappear {
            realtimeTask?.cancel()
            realtimeTask = nil
        }
        .refreshable { await load() }
        .sheet(isPresented: Binding(
            get: { connectionInviteDetailId != nil },
            set: { if !$0 { connectionInviteDetailId = nil } }
        )) {
            if let id = connectionInviteDetailId {
                ConnectionInviteNotificationDetailView(
                    inviteId: id,
                    onFinished: {
                        connectionInviteDetailId = nil
                        Task { await load() }
                    }
                )
                .environmentObject(auth)
                .environmentObject(toast)
            }
        }
    }

    private func onNotificationTap(_ n: AppNotification) async {
        await markRead(n)
        if n.type == AppNotificationType.connectionInvite {
            if let id = n.connectionInviteId {
                connectionInviteDetailId = id
                HapticFeedback.medium()
            }
        }
    }

    private func sectionHeader(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "今天" }
        if cal.isDateInYesterday(day) { return "昨天" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f.string(from: day)
    }

    private func notificationCard(_ n: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                    .fill(AppColor.primary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName(for: n.type))
                    .font(.title3)
                    .foregroundStyle(AppColor.primary)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(n.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColor.textPrimary)
                Text(n.body)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let d = n.createdAt {
                    Text(Self.shortDate.string(from: d))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
        .overlay(alignment: .leading) {
            if !n.read {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(AppColor.primary)
                    .frame(width: 4)
                    .padding(.vertical, 10)
            }
        }
    }

    private func iconName(for type: String) -> String {
        switch type {
        case AppNotificationType.dmReceived: return "bubble.left.and.bubble.right.fill"
        case AppNotificationType.inviteReceived, AppNotificationType.inviteAccepted: return "envelope.fill"
        case AppNotificationType.deskApplicationReceived, AppNotificationType.deskApplicationAccepted, AppNotificationType.deskApplicationRejected:
            return "briefcase.fill"
        case AppNotificationType.connectionInvite, AppNotificationType.connectionAccepted: return "person.2.fill"
        default: return "bell.fill"
        }
    }

    private func load() async {
        guard let uid = auth.currentUser?.id else {
            errorText = "請先登入"
            isLoading = false
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            items = try await repo.fetchNotifications(userId: uid)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func markRead(_ n: AppNotification) async {
        guard !n.read else { return }
        do {
            try await repo.markAsRead(notificationId: n.id)
            HapticFeedback.light()
            await load()
        } catch {
            HapticFeedback.error()
        }
    }

    private func markAllRead() async {
        guard let uid = auth.currentUser?.id else { return }
        markAllInFlight = true
        defer { markAllInFlight = false }
        do {
            try await repo.markAllAsRead(userId: uid)
            HapticFeedback.success()
            await load()
        } catch {
            HapticFeedback.error()
        }
    }

    private func startRealtime() {
        guard let uid = auth.currentUser?.id else { return }
        realtimeTask = repo.subscribeToNotifications(userId: uid) {
            Task { await load() }
        }
    }

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f
    }()
}

// MARK: - Connection invite from notification (PRD §8)

private struct ConnectionInviteNotificationDetailView: View {
    let inviteId: UUID
    let onFinished: () -> Void

    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @State private var invite: ConnectionInvite?
    @State private var fromProfile: UserProfile?
    @State private var loadError: String?
    @State private var actionBusy = false

    private let connectionsRepo = ConnectionRepository()
    private let usersRepo = UserRepository()

    var body: some View {
        NavigationStack {
            Group {
                if let err = loadError {
                    ContentUnavailableView("無法載入", systemImage: "exclamationmark.triangle", description: Text(err))
                } else if let inv = invite, let from = fromProfile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Label("有人想連接你", systemImage: "person.badge.plus")
                                .font(.title2.bold())
                                .foregroundStyle(AppColor.primary)
                            HStack(spacing: 12) {
                                Text(from.displayName.isEmpty ? "用戶" : from.displayName)
                                    .font(.title3.weight(.semibold))
                                if from.verificationBadgeStyle != nil {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(AppColor.gold)
                                }
                            }
                            if let msg = inv.message?.trimmingCharacters(in: .whitespacesAndNewlines), !msg.isEmpty {
                                Text(msg)
                                    .font(.body)
                                    .foregroundStyle(AppColor.textSecondary)
                                    .padding(CardChrome.padding)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                            .fill(AppColor.surfaceElevated)
                                    )
                            } else {
                                Text("對方沒有留下訊息")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.textTertiary)
                            }
                            HStack(spacing: 12) {
                                Button {
                                    Task { await decline(inv) }
                                } label: {
                                    Text("拒絕")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppColor.error.opacity(0.12))
                                        .foregroundStyle(AppColor.error)
                                        .clipShape(Capsule())
                                }
                                .disabled(actionBusy)

                                Button {
                                    Task { await accept(inv) }
                                } label: {
                                    if actionBusy {
                                        ProgressView()
                                            .tint(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                    } else {
                                        Text("接受")
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                    }
                                }
                                .background(AppColor.brandGradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .disabled(actionBusy)
                            }
                        }
                        .padding(CardChrome.padding)
                    }
                    .background(AppColor.background)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(AppColor.primary)
                        Text("載入邀請…")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("連接邀請")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { onFinished() }
                }
            }
        }
        .task { await loadInvite() }
    }

    private func loadInvite() async {
        loadError = nil
        do {
            let inv = try await connectionsRepo.fetchInvite(id: inviteId)
            invite = inv
            fromProfile = try await usersRepo.fetchUser(id: inv.fromUserId)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func accept(_ inv: ConnectionInvite) async {
        guard let uid = auth.currentUser?.id else { return }
        actionBusy = true
        defer { actionBusy = false }
        do {
            try await connectionsRepo.acceptConnectionInvite(inviteId: inv.id, currentUserId: uid)
            toast.show(.success, "已連接，可於私訊開始對話")
            HapticFeedback.success()
            onFinished()
        } catch {
            toast.show(.error, error.localizedDescription)
            HapticFeedback.error()
        }
    }

    private func decline(_ inv: ConnectionInvite) async {
        guard let uid = auth.currentUser?.id else { return }
        actionBusy = true
        defer { actionBusy = false }
        do {
            try await connectionsRepo.declineConnectionInvite(inviteId: inv.id, currentUserId: uid)
            toast.show(.info, "已拒絕邀請")
            HapticFeedback.success()
            onFinished()
        } catch {
            toast.show(.error, error.localizedDescription)
            HapticFeedback.error()
        }
    }
}
