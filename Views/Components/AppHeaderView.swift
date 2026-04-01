import SwiftUI

struct AppHeaderView: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .tracking(-0.3)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background {
            AppColor.headerGradient
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.06),
                    Color.clear,
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)
    }
}
