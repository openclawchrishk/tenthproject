import SwiftUI

/// Apple IAP placeholder (PRD §3.2) — UI only, no StoreKit transactions.
struct PremiumUpgradeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.gold, AppColor.primary)
                Text("升級至 Level 3")
                    .font(.title.bold())
                Text("解鎖 Premium 標章、更多 Desk 成員額度與進階功能。正式上線時將透過 Apple In-App Purchase 付款。")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Level 3：最多 8 位成員", systemImage: "person.3.fill")
                    Label("Premium 標章顯示", systemImage: "star.circle.fill")
                    Label("即將支援：Apple IAP", systemImage: "applelogo")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                        .fill(AppColor.cardBackground)
                        .shadow(
                            color: CardChrome.shadowColor,
                            radius: CardChrome.shadowRadiusElevated,
                            x: 0,
                            y: CardChrome.shadowYElevated
                        )
                )

                Button {
                    HapticFeedback.light()
                    // Placeholder: real purchase flow would start here.
                } label: {
                    Text("使用 Apple 內購（示範）")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.primary)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
