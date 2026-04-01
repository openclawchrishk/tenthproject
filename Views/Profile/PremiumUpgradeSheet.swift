import SwiftUI

/// Premium upgrade sheet (PRD §3.2) — UI preview; StoreKit integration pending.
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

                    comparisonTable

                    VStack(alignment: .leading, spacing: 14) {
                        benefitRow("Desk 成員上限提升至 8 人", icon: "person.3.fill")
                        benefitRow("個人檔案 Premium 標章", icon: "star.circle.fill")
                        benefitRow("優先曝光與配對（即將推出）", icon: "sparkles")
                        benefitRow("匯出 IG 限動個人卡（已提供）", icon: "photo.on.rectangle.angled")
                        benefitRow("正式上線時支援 Apple In-App Purchase", icon: "applelogo")
                    }
                    .padding(CardChrome.padding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                            .fill(AppColor.cardBackground)
                            .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                    )

                    VStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("HK$ 128")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppColor.textTertiary)
                                .strikethrough(true, color: AppColor.textTertiary)
                            Text("HK$ 98 / 月")
                                .font(.title2.bold())
                                .foregroundStyle(AppColor.textPrimary)
                        }
                        Text("限時早鳥優惠 · 正式上線前不會收費")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppColor.gold)
                        Text("對比標價突顯 Premium 價值")
                            .font(.caption2)
                            .foregroundStyle(AppColor.textTertiary)
                    }

                    Button {
                        HapticFeedback.light()
                    } label: {
                        Text("使用 Apple 內購升級")
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
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppColor.textSecondary, AppColor.secondaryGroupedSurface)
                    }
                    .accessibilityLabel("關閉")
                }
            }
        }
        .deskerSheetSpringContent()
    }

    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("方案比較")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.bottom, 12)
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Lv 1–2")
                    .font(.caption.weight(.bold))
                    .frame(width: 72, alignment: .center)
                Text("Lv 3+")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.gold)
                    .frame(width: 72, alignment: .center)
            }
            .padding(.vertical, 8)
            Divider()
            comparisonRow("基本個人檔案", basic: "✓", premium: "✓")
            comparisonRow("私訊（DM）", basic: "有限額*", premium: "無限*")
            comparisonRow("Premium 標章", basic: "—", premium: "✓")
            comparisonRow("優先曝光", basic: "—", premium: "✓")
            comparisonRow("IG 個人卡匯出", basic: "✓", premium: "✓")
            Text("* 正式上線後以產品政策為準。")
                .font(.caption2)
                .foregroundStyle(AppColor.textTertiary)
                .padding(.top, 10)
        }
        .padding(CardChrome.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
        )
    }

    private func comparisonRow(_ title: String, basic: String, premium: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(basic)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 72, alignment: .center)
                Text(premium)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: 72, alignment: .center)
            }
            .padding(.vertical, 10)
            Divider()
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
