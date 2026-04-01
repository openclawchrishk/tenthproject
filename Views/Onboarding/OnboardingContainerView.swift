import SwiftUI

#if os(iOS)
import AudioToolbox
import UserNotifications
#endif

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

            Group {
                switch viewModel.currentStep {
                case .roleSelection:
                    RoleSelectionView(viewModel: viewModel)
                        .transition(onboardingSlideTransition)
                case .basicInfo:
                    BasicInfoView(viewModel: viewModel)
                        .transition(onboardingSlideTransition)
                case .skillsAndNeeds:
                    SkillsAndNeedsView(viewModel: viewModel)
                        .transition(onboardingSlideTransition)
                case .completed:
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.82), value: viewModel.currentStep)
        }
        .background(AppColor.background)
    }

    private var onboardingSlideTransition: AnyTransition {
        if viewModel.lastStepNavigationWasForward {
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
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

struct CompletionView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var iconPulse = false
    @State private var shimmerX: CGFloat = -1
    @State private var didCelebrate = false
    @State private var checkPop: CGFloat = 0.4
    @State private var showShareCompletion = false

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
                showShareCompletion = true
                HapticFeedback.light()
            } label: {
                Label("分享完成喜悅", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
            }
            .padding(.bottom, 4)

            Button {
                DeskerUXPreferences.pendingExploreAfterOnboarding = true
                DeskerUXPreferences.showExploreSwipeTip = true
                DeskerUXPreferences.showAppTutorialAfterOnboarding = true
                Task {
                    await auth.refreshProfile()
                    DeskerAnalytics.track(.userCompleteOnboarding)
                    #if os(iOS)
                    await scheduleWelcomeLocalNotification()
                    #endif
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
        .sheet(isPresented: $showShareCompletion) {
            Group {
                if let u = auth.currentUser {
                    ShareSheetView(items: [PublicLinks.profilePublicURL(for: u)])
                } else {
                    ProgressView("載入中…")
                        .padding()
                }
            }
        }
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
                #if os(iOS)
                AudioServicesPlaySystemSound(1025)
                #endif
            }
        }
    }

    #if os(iOS)
    private func scheduleWelcomeLocalNotification() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "歡迎加入 Desker HK！"
        content.body = "開始探索你的下一個Desk"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.8, repeats: false)
        let req = UNNotificationRequest(identifier: "desker.welcome.after_onboarding", content: content, trigger: trigger)
        try? await center.add(req)
    }
    #endif

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

/// Confetti-like dots falling from the top of the field (non-interactive).
private struct CompletionConfettiField: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                let colors: [Color] = [AppColor.gold, AppColor.secondary, AppColor.teal, .white]
                let fallHeight = size.height + 80
                for i in 0..<36 {
                    let fi = CGFloat(i)
                    let x = (sin(fi * 1.1 + t * 0.35) * 0.42 + 0.5) * size.width
                    let phase = Double(i) * 0.31 + Double(t) * 1.15
                    let yRaw = CGFloat(phase.truncatingRemainder(dividingBy: Double(fallHeight)))
                    let y = yRaw - 40
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

                        Group {
                            switch viewModel.currentStep {
                            case .roleSelection:
                                RoleSelectionView(viewModel: viewModel)
                                    .environmentObject(auth)
                                    .transition(onboardingSlideTransition)
                            case .basicInfo:
                                BasicInfoView(viewModel: viewModel)
                                    .environmentObject(auth)
                                    .transition(onboardingSlideTransition)
                            case .skillsAndNeeds:
                                SkillsAndNeedsView(viewModel: viewModel)
                                    .environmentObject(auth)
                                    .transition(onboardingSlideTransition)
                            case .completed:
                                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: viewModel.currentStep)
                    }
                    .background(AppColor.background)
                    .navigationTitle(onboardingNavigationTitle)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(AppColor.background, for: .navigationBar)
                    #endif
                    .toolbar {
                        #if os(iOS)
                        ToolbarItem(placement: .topBarLeading) {
                            onboardingBackButton
                        }
                        #elseif os(macOS)
                        ToolbarItem(placement: .navigation) {
                            onboardingBackButton
                        }
                        #endif
                    }
                }
            }
        }
        .tint(AppColor.primary)
    }

    private var onboardingSlideTransition: AnyTransition {
        if viewModel.lastStepNavigationWasForward {
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    @ViewBuilder
    private var onboardingBackButton: some View {
        if showsOnboardingBackButton {
            Button {
                HapticFeedback.selection()
                viewModel.goToPreviousStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
            }
            .accessibilityLabel("返回上一步")
        }
    }

    private var showsOnboardingBackButton: Bool {
        switch viewModel.currentStep {
        case .basicInfo, .skillsAndNeeds: return true
        case .roleSelection, .completed: return false
        }
    }

    private var onboardingNavigationTitle: String {
        switch viewModel.currentStep {
        case .roleSelection: return "選擇角色"
        case .basicInfo: return "基本資料"
        case .skillsAndNeeds: return "標籤設定"
        case .completed: return ""
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
