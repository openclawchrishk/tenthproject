import SwiftUI

struct AppHeaderView: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "111827"))
                .tracking(-0.3)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "6B7280"))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background {
            LinearGradient(
                colors: [
                    Color.white,
                    Color(hex: "F9FAFB"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.07),
                    Color.clear,
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
