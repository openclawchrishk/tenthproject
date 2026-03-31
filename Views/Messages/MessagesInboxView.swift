import SwiftUI
import UIKit

/// 訊息與邀請：從 Supabase 載入並顯示。
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
                    subtitle: "對話與 Desk 邀請"
                )
                Picker("", selection: $segment) {
                    Text("訊息").tag(0)
                    Text("邀請").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                if isLoading {
                    ProgressView()
                        .padding(.top, 32)
                } else if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                } else if segment == 0 {
                    messageList
                } else {
                    inviteList
                }
                Spacer(minLength: 0)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
    }

    private var messageList: some View {
        Group {
            if messages.isEmpty {
                ContentUnavailableView("沒有訊息", systemImage: "bubble.left.and.bubble.right", description: Text("開始與其他用戶對話後會顯示於此"))
                    .padding(.top, 24)
            } else {
                List(messages) { item in
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
                .listStyle(.insetGrouped)
            }
        }
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
                .listStyle(.insetGrouped)
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
