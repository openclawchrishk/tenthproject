import SwiftUI

struct SkillsAndNeedsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository
    @State private var isSaving = false
    @State private var saveError: String?

    private let industryIcons: [String: String] = [
        "金融科技": "banknote.fill", "教育": "book.fill", "醫療健康": "heart.fill",
        "電商": "cart.fill", "SaaS": "cloud.fill", "AI / 數據": "brain.head.profile",
        "區塊鏈": "bitcoinsign.circle.fill", "消費品牌": "bag.fill"
    ]

    private let skillIcons: [String: String] = [
        "產品": "cube.fill", "設計": "paintbrush.fill", "前端": "chevron.left.forwardslash.chevron.right",
        "後端": "server.rack", "市場": "megaphone.fill", "營運": "gearshape.fill",
        "投資": "chart.line.uptrend.xyaxis", "法律": "scale.3d"
    ]

    private let needIcons: [String: String] = [
        "技術合夥人": "wrench.and.screwdriver.fill", "資金": "banknote.fill",
        "導師": "person.badge.clock.fill", "市場渠道": "arrow.triangle.branch",
        "招聘": "person.badge.plus", "辦公空間": "building.2.fill"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColor.secondary)

                    Text("標籤設定")
                        .font(.title.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    Text("選擇你嘅產業、技能同需求")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Industry tags
                tagSection(
                    title: "產業標籤",
                    subtitle: "你關注或從事的產業",
                    icon: "building.2.fill",
                    options: OnboardingViewModel.industryOptions,
                    icons: industryIcons,
                    selection: $viewModel.industryTags,
                    accent: AppColor.primary
                )

                // Skills
                tagSection(
                    title: "我的技能",
                    subtitle: "你擅長的能力",
                    icon: "star.fill",
                    options: OnboardingViewModel.skillOptions,
                    icons: skillIcons,
                    selection: $viewModel.skills,
                    accent: AppColor.secondary
                )

                // Needs
                tagSection(
                    title: "我需要",
                    subtitle: "希望獲得的支援",
                    icon: "hand.raised.fill",
                    options: OnboardingViewModel.needOptions,
                    icons: needIcons,
                    selection: $viewModel.needs,
                    accent: AppColor.accentOrange
                )

                // Error
                if let saveError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColor.error)
                        Text(saveError)
                            .font(.subheadline)
                            .foregroundStyle(AppColor.error)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColor.error.opacity(0.1))
                    .cornerRadius(CardChrome.cornerRadiusMedium)
                }

                // Save button
                Button {
                    Task { await saveAndContinue() }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("完成設定")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [AppColor.primary, AppColor.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .opacity(isSaving ? 0.65 : 1)
                }
                .disabled(isSaving)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(AppColor.background.ignoresSafeArea())
        .overlay {
            if isSaving {
                ZStack {
                    Color.black.opacity(0.04).ignoresSafeArea()
                    ProgressView()
                        .tint(AppColor.primary)
                        .padding(22)
                        .background(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                }
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func tagSection(
        title: String,
        subtitle: String,
        icon: String,
        options: [String],
        icons: [String: String],
        selection: Binding<Set<String>>,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                if !selection.wrappedValue.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.success)
                        .accessibilityLabel("已完成選擇")
                }
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selection.wrappedValue.contains(option)
                        Button {
                            HapticFeedback.light()
                            if isSelected {
                                selection.wrappedValue.remove(option)
                            } else {
                                selection.wrappedValue.insert(option)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if let iconName = icons[option] {
                                    Image(systemName: iconName)
                                        .font(.caption)
                                }
                                Text(option)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? accent : accent.opacity(0.1))
                            .foregroundStyle(isSelected ? .white : accent)
                            .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                            .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.05), radius: 3, x: 0, y: 1)
                            .overlay(
                                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                                    .stroke(isSelected ? accent : AppColor.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(DeskerChipPressStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func saveAndContinue() async {
        guard auth.session != nil else {
            saveError = "尚未登入，無法儲存。請返回重新登入。"
            return
        }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            try await viewModel.persistSkillsAndNeeds(auth: auth)
            viewModel.proceedToNextStep()
        } catch {
            saveError = "儲存失敗：\(error.localizedDescription)"
            HapticFeedback.error()
        }
    }
}

struct SkillsAndNeedsView_Previews: PreviewProvider {
    static var previews: some View {
        SkillsAndNeedsView(viewModel: OnboardingViewModel())
            .environmentObject(AuthRepository())
    }
}
