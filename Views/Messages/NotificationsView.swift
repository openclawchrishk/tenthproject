import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var items: [AppNotification] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var realtimeTask: Task<Void, Never>?

    private let repo = NotificationRepository()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入通知…")
            } else if let errorText {
                ContentUnavailableView("載入失敗", systemImage: "exclamationmark.triangle", description: Text(errorText))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("重試") { Task { await load() } }
                        }
                    }
            } else if items.isEmpty {
                ContentUnavailableView("沒有通知", systemImage: "bell", description: Text("新邀請、申請與訊息會顯示於此"))
            } else {
                List {
                    ForEach(items, id: \.id) { n in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(n.title)
                                    .font(.headline)
                                Spacer()
                                if !n.read {
                                    Circle()
                                        .fill(AppColor.primary)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            Text(n.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let d = n.createdAt {
                                Text(Self.shortDate.string(from: d))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await markRead(n) }
                        }
                    }
                }
                .deskerInsetGroupedListStyle()
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
            items = try await repo.fetchNotifications(for: uid)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func markRead(_ n: AppNotification) async {
        guard !n.read else { return }
        do {
            try await repo.markRead(notificationId: n.id)
            HapticFeedback.light()
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
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f
    }()
}
