import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var industryTags: Set<String> = []
    @State private var skills: Set<String> = []
    @State private var needs: Set<String> = []
    @State private var isSaving = false
    @State private var banner: String?

    private let userRepo = UserRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView(
                    title: "個人資料",
                    subtitle: auth.currentUser?.displayName ?? ""
                )
                if let user = auth.currentUser {
                    Form {
                        Section("帳戶") {
                            LabeledContent("名稱") {
                                Text(user.displayName)
                            }
                            LabeledContent("角色") {
                                Text(user.role.localizedName)
                            }
                        }
                        Section {
                            TagSection(
                                title: "產業標籤",
                                subtitle: "點選以編輯，完成後按儲存",
                                options: OnboardingViewModel.industryOptions,
                                selection: $industryTags,
                                accent: AppColor.primary
                            )
                            TagSection(
                                title: "技能",
                                subtitle: "",
                                options: OnboardingViewModel.skillOptions,
                                selection: $skills,
                                accent: AppColor.secondary
                            )
                            TagSection(
                                title: "需求",
                                subtitle: "",
                                options: OnboardingViewModel.needOptions,
                                selection: $needs,
                                accent: AppColor.accentOrange
                            )
                        } header: {
                            Text("產業、技能與需求")
                        }

                        if let banner {
                            Section {
                                Text(banner)
                                    .font(.footnote)
                                    .foregroundStyle(bannerForeground(banner))
                            }
                        }

                        Section {
                            Button {
                                Task { await save() }
                            } label: {
                                if isSaving {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                        Spacer()
                                    }
                                } else {
                                    Text("儲存變更")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(isSaving)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .overlay {
                        if isSaving {
                            ZStack {
                                Color.black.opacity(0.06).ignoresSafeArea()
                                VStack(spacing: 10) {
                                    ProgressView()
                                    Text("儲存中…")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(28)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("尚未載入資料", systemImage: "person.crop.circle.badge.questionmark")
                }
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .task {
            await auth.refreshProfile()
            syncFromProfile()
        }
        .onChange(of: auth.currentUser?.id) { _ in
            syncFromProfile()
        }
    }

    private func syncFromProfile() {
        guard let u = auth.currentUser else { return }
        industryTags = Set(u.industryTags)
        skills = Set(u.skills)
        needs = Set(u.needs)
    }

    private func save() async {
        guard var profile = auth.currentUser else { return }
        isSaving = true
        banner = nil
        defer { isSaving = false }
        do {
            profile.industryTags = Array(industryTags)
            profile.skills = Array(skills)
            profile.needs = Array(needs)
            try await userRepo.upsertUser(profile)
            await auth.refreshProfile()
            banner = "已儲存"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            banner = "儲存失敗：\(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func bannerForeground(_ banner: String) -> Color {
        if banner.contains("失敗") { return .red }
        if banner.contains("已儲存") { return Color(red: 0.2, green: 0.65, blue: 0.35) }
        return .secondary
    }
}

private struct TagSection: View {
    let title: String
    let subtitle: String
    let options: [String]
    @Binding var selection: Set<String>
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let on = selection.contains(option)
                    Button {
                        if on { selection.remove(option) } else { selection.insert(option) }
                    } label: {
                        Text(option)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(on ? accent.opacity(0.2) : Color(UIColor.secondarySystemGroupedBackground))
                            .foregroundStyle(on ? accent : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(on ? accent : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
