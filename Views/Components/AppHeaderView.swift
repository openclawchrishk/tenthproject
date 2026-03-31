import SwiftUI

struct AppHeaderView: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "1C1C1E"), Color(hex: "3A3A3C")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.labelSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            ZStack {
                AppColor.headerGradient
                LinearGradient(
                    colors: [Color.white.opacity(0.95), Color(hex: "F5F7FA")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}
