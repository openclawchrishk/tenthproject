import SwiftUI

/// First-session feature highlights after onboarding; skip sets `DeskerUXPreferences.appTutorialDismissed`.
struct AppTutorialOverlay: View {
    let onFinish: () -> Void

    @State private var step = 0

    private let pages: [(String, String, String)] = [
        ("person.2.fill", "探索", "發掘香港與大灣區創業者，向右滑收藏心水人選"),
        ("briefcase.fill", "Desk", "建立或加入 Desk，招募團隊與展示項目"),
        ("bubble.left.and.bubble.right.fill", "訊息", "私訊、通知、Desk 邀請與人脈集中管理"),
        ("person.fill", "我的", "完善檔案、邀請朋友與升級 Premium"),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { }
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        HapticFeedback.selection()
                        DeskerUXPreferences.appTutorialDismissed = true
                        onFinish()
                    } label: {
                        Text("跳過")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppColor.primary.opacity(0.2))
                            .frame(width: 100, height: 100)
                        Image(systemName: pages[step].0)
                            .font(.system(size: 44))
                            .foregroundStyle(AppColor.primary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    Text(pages[step].1)
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.textPrimary)
                    Text(pages[step].2)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .lineSpacing(4)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: 520)
                .background(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .fill(AppColor.cardBackground)
                        .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                )
                .padding(.horizontal, CardChrome.padding)

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? AppColor.primary : AppColor.textTertiary.opacity(0.35))
                            .frame(width: i == step ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: step)
                    }
                }
                .padding(.top, 20)

                Spacer()

                Button {
                    HapticFeedback.medium()
                    if step < pages.count - 1 {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            step += 1
                        }
                    } else {
                        DeskerUXPreferences.appTutorialDismissed = true
                        onFinish()
                    }
                } label: {
                    Text(step < pages.count - 1 ? "下一步" : "開始使用")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColor.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(DeskerButtonPressStyle())
                .padding(.horizontal, CardChrome.padding)
                .padding(.bottom, 36)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
