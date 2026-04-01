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
    @State private var blockActionError: String?

    private let dmRepo = DMRepository()
    private let moderation = ReportBlockRepository()

    var body: some View {
        VStack(spacing: 0) {
            if let blockActionError {
                Text(blockActionError)
                    .font(.footnote)
                    .foregroundStyle(AppColor.error)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, CardChrome.padding)
                    .padding(.vertical, 10)
                    .background(AppColor.error.opacity(0.1))
            }
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView("載入對話…")
                        .tint(AppColor.primary)
                }
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
                    #if os(iOS)
                    .scrollDismissesKeyboard(.interactively)
                    #endif
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isLoading, errorText == nil, conversation != nil {
                dmInputBar
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
                guard let uid = auth.currentUser?.id else {
                    throw RepositoryError.notAuthenticated
                }
                try await moderation.submitReport(draft, reporterId: uid)
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

    private var dmInputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("傳送訊息…", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                #if os(iOS)
                .submitLabel(.send)
                #endif
                .onSubmit { Task { await send() } }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .fill(AppColor.cardBackground)
                        .shadow(color: CardChrome.buttonShadowColor, radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
                )
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, AppColor.secondary.opacity(0.9))
                    .padding(12)
                    .background(AppColor.brandGradient, in: Circle())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(CardChrome.padding)
        .background(AppColor.background)
    }

    private func messageRow(_ msg: DirectMessage) -> some View {
        let mine = msg.senderId == auth.currentUser?.id
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(msg.content)
                .padding(14)
                .foregroundStyle(AppColor.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .fill(mine ? AppColor.primary.opacity(0.18) : AppColor.cardBackground)
                        .shadow(color: CardChrome.buttonShadowColor, radius: 5, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .stroke(mine ? AppColor.primary.opacity(0.35) : AppColor.textTertiary.opacity(0.18), lineWidth: 1)
                )
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
            messages = try await dmRepo.fetchMessages(conversationId: conv.id)
            startRealtime(conv.id)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadMessages() async {
        guard let c = conversation else { return }
        do {
            messages = try await dmRepo.fetchMessages(conversationId: c.id)
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
            try await dmRepo.sendMessage(conversationId: c.id, senderId: uid, content: text)
            HapticFeedback.light()
            await loadMessages()
        } catch {
            errorText = error.localizedDescription
            HapticFeedback.error()
        }
    }

    private func blockPeer() async {
        guard let uid = auth.currentUser?.id else { return }
        blockActionError = nil
        do {
            try await moderation.blockUser(blockerId: uid, blockedId: peerId)
            HapticFeedback.success()
        } catch {
            HapticFeedback.error()
            blockActionError = "無法封鎖用戶，請稍後再試"
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
