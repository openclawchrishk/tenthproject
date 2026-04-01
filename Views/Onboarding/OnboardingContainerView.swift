import SwiftUI

struct OnboardingContainerView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index <= currentStepIndex ? AppColor.primary : AppColor.textSecondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)

            Text("第 \(currentStepIndex + 1) 步，共 3 步")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.top, 8)

            // Content
            TabView(selection: $viewModel.currentStep) {
                RoleSelectionView(viewModel: viewModel)
                    .tag(OnboardingStep.roleSelection)

                BasicInfoView(viewModel: viewModel)
                    .tag(OnboardingStep.basicInfo)

                SkillsAndNeedsView(viewModel: viewModel)
                    .tag(OnboardingStep.skillsAndNeeds)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentStep)
        }
        .background(AppColor.background)
    }

    private var currentStepIndex: Int {
        switch viewModel.currentStep {
        case .roleSelection: return 0
        case .basicInfo: return 1
        case .skillsAndNeeds: return 2
        case .completed: return 3
        }
    }
}

struct CompletionView: View {
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppColor.success.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.success, AppColor.primary)
                }

                Text("歡迎加入 Desker HK！")
                    .font(.title.bold())
                    .foregroundStyle(AppColor.textPrimary)

                Text("你已完成設定，可以開始探索創業社群了")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                featureRow(icon: "person.2.fill", color: AppColor.primary, title: "探索社群", desc: "發掘香港、大灣區創業機會")
                featureRow(icon: "briefcase.fill", color: AppColor.secondary, title: "建立或加入 Desk", desc: "找到你嘅理想夥伴或投資者")
                featureRow(icon: "bubble.left.and.bubble.right.fill", color: AppColor.teal, title: "即時連接", desc: "與其他創業者即時溝通")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                Task {
                    await auth.refreshProfile()
                }
            } label: {
                Text("開始探索")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.brandGradient)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColor.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        NavigationStack {
            switch viewModel.currentStep {
            case .roleSelection:
                RoleSelectionView(viewModel: viewModel)
                    .environmentObject(auth)

            case .basicInfo:
                BasicInfoView(viewModel: viewModel)
                    .environmentObject(auth)

            case .skillsAndNeeds:
                SkillsAndNeedsView(viewModel: viewModel)
                    .environmentObject(auth)

            case .completed:
                CompletionView()
                    .environmentObject(auth)
                    .onAppear {
                        Task {
                            await viewModel.finalizeOnboarding(auth: auth)
                        }
                    }
            }
        }
    }
}
