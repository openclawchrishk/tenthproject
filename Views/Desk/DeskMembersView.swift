import SwiftUI

/// Active desk members: founder crown, skills/tags, founder-only remove (PRD §10).
struct DeskMembersView: View {
    let desk: Desk

    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @State private var members: [DeskMember] = []
    @State private var profiles: [UUID: UserProfile] = [:]
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var removeTarget: DeskMember?

    private let deskRepo = DeskRepository()
    private let userRepo = UserRepository()

    private var isFounder: Bool {
        auth.currentUser?.id == desk.founderId
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入成員…")
                    .tint(AppColor.primary)
                    .frame(maxHeight: .infinity)
            } else if let errorText {
                ContentUnavailableView("無法載入", systemImage: "exclamationmark.triangle", description: Text(errorText))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("重試") { Task { await load() } }
                        }
                    }
            } else {
                List {
                    ForEach(members) { m in
                        memberRow(m)
                            .listRowBackground(AppColor.cardBackground)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Desk 成員")
        .deskerInlineNavigationTitle()
        .task { await load() }
        .refreshable { await load() }
        .alert("移除此成員？", isPresented: Binding(
            get: { removeTarget != nil },
            set: { if !$0 { removeTarget = nil } }
        )) {
            Button("移除", role: .destructive) {
                if let m = removeTarget { Task { await removeMember(m) } }
            }
            Button("取消", role: .cancel) { removeTarget = nil }
        } message: {
            Text("對方將無法再存取此 Desk 的群組聊天。")
        }
    }

    @ViewBuilder
    private func memberRow(_ m: DeskMember) -> some View {
        let founder = m.userId == desk.founderId
        let profile = profiles[m.userId]
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                memberAvatar(profile: profile)
                if founder {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(AppColor.gold)
                        .padding(4)
                        .background(Circle().fill(AppColor.primary))
                        .offset(x: 4, y: 4)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(profile?.displayName ?? "用戶")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    if founder {
                        Text("創辦人")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColor.gold.opacity(0.2))
                            .foregroundStyle(AppColor.gold)
                            .clipShape(Capsule())
                    }
                    if profile?.verificationBadgeStyle != nil {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColor.gold)
                    }
                }
                if let tags = tagStrings(for: profile), !tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), alignment: .leading)], alignment: .leading, spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColor.primary.opacity(0.1))
                                .foregroundStyle(AppColor.primary)
                                .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            if isFounder, !founder, let uid = auth.currentUser?.id, uid == desk.founderId {
                Button {
                    removeTarget = m
                } label: {
                    Image(systemName: "person.fill.xmark")
                        .foregroundStyle(AppColor.error)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
    }

    private func tagStrings(for profile: UserProfile?) -> [String]? {
        guard let profile else { return nil }
        let merged = Array(Set(profile.skills + profile.industryTags)).sorted()
        return merged.isEmpty ? nil : merged
    }

    private func memberAvatar(profile: UserProfile?) -> some View {
        Group {
            if let s = profile?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                CachedAsyncImage(url: url, maxPixelDimension: 200) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                            .tint(AppColor.primary)
                    case .failure:
                        placeholderInitials(profile?.displayName ?? "?")
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
            } else {
                placeholderInitials(profile?.displayName ?? "?")
            }
        }
    }

    private func placeholderInitials(_ name: String) -> some View {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = t.first.map(String.init) ?? "?"
        return ZStack {
            Circle()
                .fill(AppColor.brandGradient)
                .frame(width: 52, height: 52)
            Text(initial)
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let rows = try await deskRepo.fetchDeskMembers(deskId: desk.id)
            members = rows
            var map: [UUID: UserProfile] = [:]
            for row in rows {
                if let u = try? await userRepo.fetchUser(id: row.userId) {
                    map[row.userId] = u
                }
            }
            profiles = map
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func removeMember(_ m: DeskMember) async {
        guard let uid = auth.currentUser?.id else { return }
        removeTarget = nil
        do {
            try await deskRepo.removeDeskMember(deskId: desk.id, memberUserId: m.userId, founderId: uid)
            toast.show(.success, "已移除成員")
            HapticFeedback.success()
            await load()
        } catch {
            toast.show(.error, error.localizedDescription)
            HapticFeedback.error()
        }
    }
}
