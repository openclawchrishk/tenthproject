import SwiftUI

/// Apple IAP placeholder (PRD §3.2) — UI only, no StoreKit transactions.
struct PremiumUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(hex: "2D346D"),
                                Color(hex: "4A3F7A"),
                                Color(hex: "C9A227"),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous))

                        VStack(spacing: 14) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.white)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                            Text("Level 3 Premium")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text("解鎖更高成員額度、Premium 標章與進階功能")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(28)
                    }
                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)

                    VStack(alignment: .leading, spacing: 14) {
                        benefitRow("Desk 成員上限提升至 8 人", icon: "person.3.fill")
                        benefitRow("個人檔案 Premium 標章", icon: "star.circle.fill")
                        benefitRow("優先曝光與配對（即將推出）", icon: "sparkles")
                        benefitRow("正式上線時支援 Apple In-App Purchase", icon: "applelogo")
                    }
                    .padding(CardChrome.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                            .fill(AppColor.cardBackground)
                            .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                    )

                    VStack(spacing: 8) {
                        Text("HK$ 98 / 月")
                            .font(.title2.bold())
                            .foregroundStyle(AppColor.textPrimary)
                        Text("示範價格 · 正式上線前不會收費")
                            .font(.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    Button {
                        HapticFeedback.light()
                    } label: {
                        Text("使用 Apple 內購升級（示範）")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "C9A227"), AppColor.primary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .deskerButtonShadow()
                }
                .padding(CardChrome.padding)
                .padding(.bottom, 24)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Premium")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }

    private func benefitRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppColor.teal)
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppColor.primary)
                .frame(width: 24)
            Text(text)
                .font(.body)
                .foregroundStyle(AppColor.textPrimary)
        }
    }
}
