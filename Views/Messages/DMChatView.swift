import SwiftUI

struct DMChatView: View {
    let peerId: UUID
    let peerDisplayName: String

    @EnvironmentObject private var auth: AuthRepository
    @State private var conversation: Conversation?
    @State private var messages: [DirectMessage] = []
    @State private var inputText = ""
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var realtimeTask: Task<Void, Never>?

    @State private var showReportUser = false

    private let dmRepo = DMRepository()
    private let moderation = ReportBlockRepository()

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("載入對話…")
                    .frame(maxHeight: .infinity)
            } else if let errorText {
                ContentUnavailableView("無法載入", systemImage: "exclamationmark.triangle", description: Text(errorText))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("重試") { Task { await bootstrap() } }
                        }
                    }
            } else if conversation == nil {
                ContentUnavailableView("無法開啟對話", systemImage: "bubble.left.and.bubble.right")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages, id: \.id) { msg in
                                messageRow(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                HStack(spacing: 12) {
                    TextField("傳送訊息…", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AppColor.secondary)
                            .padding(10)
                            .background(AppColor.primary, in: Circle())
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(AppColor.background)
            }
        }
        .navigationTitle(peerDisplayName)
        .deskerInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showReportUser = true
                    } label: {
                        Label("檢舉用戶", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        Task { await blockPeer() }
                    } label: {
                        Label("封鎖用戶", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.primary, AppColor.secondary)
                }
            }
        }
        .sheet(isPresented: $showReportUser) {
            ReportSheetView(targetType: .user, targetId: peerId) { draft in
                guard let uid = auth.currentUser?.id else { return }
                try? await moderation.submitReport(draft, reporterId: uid)
            }
        }
        .task {
            await bootstrap()
        }
        .onDisappear {
            realtimeTask?.cancel()
            realtimeTask = nil
        }
    }

    private func messageRow(_ msg: DirectMessage) -> some View {
        let mine = msg.senderId == auth.currentUser?.id
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(msg.content)
                .padding(12)
                .background(mine ? AppColor.primary.opacity(0.2) : AppColor.secondaryGroupedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !mine { Spacer(minLength: 40) }
        }
    }

    private func bootstrap() async {
        guard let uid = auth.currentUser?.id else {
            errorText = "尚未登入"
            isLoading = false
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let conv = try await dmRepo.getOrCreateConversation(currentUserId: uid, peerId: peerId)
            conversation = conv
            messages = try await dmRepo.fetchDirectMessages(conversationId: conv.id)
            startRealtime(conv.id)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadMessages() async {
        guard let c = conversation else { return }
        do {
            messages = try await dmRepo.fetchDirectMessages(conversationId: c.id)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func send() async {
        guard let uid = auth.currentUser?.id, let c = conversation else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        do {
            try await dmRepo.sendDirectMessage(conversationId: c.id, senderId: uid, content: text)
            HapticFeedback.light()
            await loadMessages()
        } catch {
            errorText = error.localizedDescription
            HapticFeedback.error()
        }
    }

    private func blockPeer() async {
        guard let uid = auth.currentUser?.id else { return }
        do {
            try await moderation.blockUser(blockerId: uid, blockedId: peerId)
            HapticFeedback.success()
        } catch {
            HapticFeedback.error()
        }
    }

    private func startRealtime(_ conversationId: UUID) {
        realtimeTask?.cancel()
        realtimeTask = dmRepo.subscribeToDirectMessages(conversationId: conversationId) {
            Task { @MainActor in
                await loadMessages()
            }
        }
    }
}
