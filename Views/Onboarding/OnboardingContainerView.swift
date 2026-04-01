import SwiftUI

struct OnboardingContainerView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        VStack(spacing: 0) {
            onboardingProgressDots
                .padding(.horizontal, 32)
                .padding(.top, 16)

            Text("第 \(currentStepIndex + 1) 步，共 3 步")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.top, 8)

            TabView(selection: $viewModel.currentStep) {
                RoleSelectionView(viewModel: viewModel)
                    .tag(OnboardingViewModel.OnboardingStep.roleSelection)

                BasicInfoView(viewModel: viewModel)
                    .tag(OnboardingViewModel.OnboardingStep.basicInfo)

                SkillsAndNeedsView(viewModel: viewModel)
                    .tag(OnboardingViewModel.OnboardingStep.skillsAndNeeds)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep)
        }
        .background(AppColor.background)
    }

    private var onboardingProgressDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                let current = min(currentStepIndex, 2)
                let isCurrent = index == current
                Circle()
                    .fill(isCurrent ? AppColor.primary : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(AppColor.primary.opacity(isCurrent ? 0 : 0.4), lineWidth: 2)
                    )
            }
        }
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
    @State private var iconPulse = false
    @State private var shimmerX: CGFloat = -1
    @State private var didCelebrate = false
    @State private var checkPop: CGFloat = 0.4

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    CompletionConfettiField()
                        .frame(width: 260, height: 200)

                    Circle()
                        .fill(AppColor.success.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(iconPulse ? 1.06 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: iconPulse)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColor.success, AppColor.primary)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                        .scaleEffect(checkPop)
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
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColor.brandGradient)
                    .cornerRadius(CardChrome.cornerRadiusMedium)
                    .overlay {
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.45), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 0.45)
                            .offset(x: shimmerX * geo.size.width)
                            .blendMode(.overlay)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                    }
                    .shadow(color: CardChrome.buttonShadowColor, radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
            }
            .buttonStyle(DeskerButtonPressStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
        .onAppear {
            iconPulse = true
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                shimmerX = 1.2
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
                checkPop = 1.0
            }
            if !didCelebrate {
                didCelebrate = true
                HapticFeedback.success()
            }
        }
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

/// Lightweight confetti-like dots drifting upward (non-interactive).
private struct CompletionConfettiField: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                let colors: [Color] = [AppColor.gold, AppColor.secondary, AppColor.teal, .white]
                for i in 0..<36 {
                    let fi = CGFloat(i)
                    let x = (sin(fi * 1.1 + t * 0.8) * 0.42 + 0.5) * size.width
                    let y = (CGFloat((Double(i * 7) + t * 55.0).truncatingRemainder(dividingBy: Double(size.height + 40))) - 20)
                    let c = colors[Int(i) % colors.count].opacity(0.55 + Double(i % 3) * 0.12)
                    let r = CGRect(x: x, y: y, width: 5 + (i % 3 == 0 ? 3 : 0), height: 7 + (i % 4 == 0 ? 4 : 0))
                    context.fill(Path(ellipseIn: r), with: .color(c))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.currentStep == .completed {
                    CompletionView()
                        .environmentObject(auth)
                        .onAppear {
                            Task {
                                await viewModel.finalizeOnboarding(auth: auth)
                            }
                        }
                } else {
                    VStack(spacing: 0) {
                        onboardingProgressDots
                            .padding(.horizontal, 32)
                            .padding(.top, 16)

                        Text("第 \(currentStepIndex + 1) 步，共 3 步")
                            .font(.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.top, 8)

                        TabView(selection: $viewModel.currentStep) {
                            RoleSelectionView(viewModel: viewModel)
                                .environmentObject(auth)
                                .tag(OnboardingViewModel.OnboardingStep.roleSelection)

                            BasicInfoView(viewModel: viewModel)
                                .environmentObject(auth)
                                .tag(OnboardingViewModel.OnboardingStep.basicInfo)

                            SkillsAndNeedsView(viewModel: viewModel)
                                .environmentObject(auth)
                                .tag(OnboardingViewModel.OnboardingStep.skillsAndNeeds)
                        }
                        #if os(iOS)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        #endif
                        .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep)
                    }
                    .background(AppColor.background)
                }
            }
        }
    }

    private var onboardingProgressDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                let current = min(currentStepIndex, 2)
                let isCurrent = index == current
                Circle()
                    .fill(isCurrent ? AppColor.primary : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(AppColor.primary.opacity(isCurrent ? 0 : 0.4), lineWidth: 2)
                    )
            }
        }
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
