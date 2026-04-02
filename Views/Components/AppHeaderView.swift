import SwiftUI

struct AppHeaderView: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.textPrimary, AppColor.textPrimary.opacity(0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .tracking(-0.8)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 18)
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
    }
}
