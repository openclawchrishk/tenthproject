import SwiftUI

struct DeskGroupChatView: View {
    let desk: Desk

    @EnvironmentObject private var auth: AuthRepository
    @State private var messages: [DeskMessage] = []
    @State private var members: [DeskMember] = []
    @State private var inputText = ""
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var canAccess = false
    @State private var realtimeTask: Task<Void, Never>?
    @State private var memberToRemove: DeskMember?
    @State private var showReport = false
    @State private var senderCache: [UUID: String] = [:]

    private let deskRepo = DeskRepository()
    private let chatRepo = DeskChatRepository()
    private let userRepo = UserRepository()
    private let reports = ReportBlockRepository()

    private var isFounder: Bool {
        auth.currentUser?.id == desk.founderId
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("載入群組聊天…")
                    .tint(AppColor.primary)
                    .frame(maxHeight: .infinity)
            } else if let errorText {
                ContentUnavailableView("無法使用", systemImage: "exclamationmark.triangle", description: Text(errorText))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("重試") { Task { await loadAccessAndMessages() } }
                        }
                    }
            } else if !canAccess {
                ContentUnavailableView("僅限成員", systemImage: "person.2.slash", description: Text("加入此 Desk 後即可使用群組聊天。"))
            } else {
                memberSection
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages, id: \.id) { msg in
                            deskMessageRow(msg)
                        }
                    }
                    .padding()
                }
                HStack(spacing: 12) {
                    TextField("群組訊息…", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await send() }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AppColor.secondary)
                            .padding(10)
                            .background(AppColor.secondary, in: Circle())
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(AppColor.background)
            }
        }
        .navigationTitle("群組聊天")
        .deskerInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showReport = true
                } label: {
                    Image(systemName: "flag")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.accentOrange, AppColor.primary)
                }
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheetView(targetType: .desk, targetId: desk.id) { draft in
                guard let uid = auth.currentUser?.id else {
                    throw UserRepositoryError.notAuthenticated
                }
                try await reports.submitReport(draft, reporterId: uid)
            }
        }
        .task {
            await loadAccessAndMessages()
            startRealtime()
        }
        .onDisappear {
            realtimeTask?.cancel()
            realtimeTask = nil
        }
        .alert("移除成員？", isPresented: Binding(
            get: { memberToRemove != nil },
            set: { if !$0 { memberToRemove = nil } }
        )) {
            Button("移除", role: .destructive) {
                if let m = memberToRemove {
                    Task { await removeMember(m) }
                }
            }
            Button("取消", role: .cancel) { memberToRemove = nil }
        } message: {
            Text("確定從 Desk 移除此成員？")
        }
    }

    @ViewBuilder
    private var memberSection: some View {
        if !members.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("成員")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ForEach(members) { m in
                    HStack {
                        Text(senderCache[m.userId] ?? "…")
                            .font(.subheadline)
                        Spacer()
                        if isFounder, m.userId != desk.founderId {
                            Button("移除") {
                                memberToRemove = m
                                HapticFeedback.light()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(AppColor.secondaryGroupedSurface, in: RoundedRectangle(cornerRadius: CardChrome.cornerRadius))
            .padding(.horizontal)
        }
    }

    private func deskMessageRow(_ msg: DeskMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(senderLabel(msg.senderId))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(msg.content)
                .font(.body)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.secondaryGroupedSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func senderLabel(_ id: UUID) -> String {
        if id == desk.founderId { return "創辦人" }
        return senderCache[id] ?? "成員"
    }

    private func loadAccessAndMessages() async {
        guard let uid = auth.currentUser?.id else {
            errorText = "請先登入"
            isLoading = false
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            canAccess = try await deskRepo.canAccessDeskChat(deskId: desk.id, userId: uid, founderId: desk.founderId)
            guard canAccess else { return }
            async let m = deskRepo.fetchDeskMembers(deskId: desk.id)
            async let msgs = chatRepo.fetchMessages(deskId: desk.id)
            members = try await m
            messages = try await msgs
            await loadSenderNames()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadSenderNames() async {
        var map: [UUID: String] = [:]
        for m in members {
            if let u = try? await userRepo.fetchUser(id: m.userId) {
                map[m.userId] = u.displayName.isEmpty ? "用戶" : u.displayName
            }
        }
        if let f = try? await userRepo.fetchUser(id: desk.founderId) {
            map[desk.founderId] = f.displayName.isEmpty ? "創辦人" : f.displayName
        }
        let senderIds = Set(messages.map(\.senderId))
        for sid in senderIds where map[sid] == nil {
            if let u = try? await userRepo.fetchUser(id: sid) {
                map[sid] = u.displayName.isEmpty ? "用戶" : u.displayName
            }
        }
        senderCache = map
    }

    private func send() async {
        guard let uid = auth.currentUser?.id else { return }
        let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        inputText = ""
        do {
            try await chatRepo.sendMessage(deskId: desk.id, senderId: uid, content: t)
            HapticFeedback.success()
            messages = try await chatRepo.fetchMessages(deskId: desk.id)
            await loadSenderNames()
        } catch {
            errorText = error.localizedDescription
            HapticFeedback.error()
        }
    }

    private func removeMember(_ m: DeskMember) async {
        guard let uid = auth.currentUser?.id else { return }
        do {
            try await deskRepo.removeDeskMember(deskId: desk.id, memberUserId: m.userId, founderId: uid)
            members = try await deskRepo.fetchDeskMembers(deskId: desk.id)
            memberToRemove = nil
            HapticFeedback.success()
        } catch {
            errorText = error.localizedDescription
            HapticFeedback.error()
        }
    }

    private func startRealtime() {
        realtimeTask?.cancel()
        realtimeTask = chatRepo.subscribeToDeskMessages(deskId: desk.id) {
            Task { @MainActor in
                messages = (try? await chatRepo.fetchMessages(deskId: desk.id)) ?? []
                await loadSenderNames()
            }
        }
    }
}
