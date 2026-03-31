import SwiftUI

struct VerificationBadgeView: View {
    let style: VerificationBadgeStyle

    var body: some View {
        Image(systemName: "checkmark.shield.fill")
            .font(.caption)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .padding(4)
            .background(color.opacity(0.25))
            .clipShape(Circle())
            .accessibilityLabel(label)
    }

    private var color: Color {
        switch style {
        case .investor: return AppColor.investorBadge
        case .expert: return AppColor.expertBadge
        }
    }

    private var label: String {
        switch style {
        case .investor: return "已認證投資者"
        case .expert: return "已認證專家"
        }
    }
}
