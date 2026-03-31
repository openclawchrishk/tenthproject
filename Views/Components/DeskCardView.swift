import SwiftUI
import UIKit

/// Swipe-style card for Explore; **再看一次** bumps `refreshTrigger` so the parent reloads content.
struct DeskCardView: View {
    let desk: Desk
    let onViewAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.primary, AppColor.secondary)
                Text(desk.name)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Spacer()
                StatusPill(status: desk.status)
            }

            Text(desk.pitch)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = desk.detailedDescription, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("需求與期望", systemImage: "checklist")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.secondary)
                Text(desk.expectations ?? desk.fundingNeeds ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("技能 / 角色", systemImage: "person.3.fill")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.accentOrange)
                Text(desk.skillsSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }

            HStack {
                Label("\(desk.currentMemberCount)/\(desk.memberLimit) 人", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.primary)
                Spacer()
                if let created = desk.createdAt {
                    Text(Self.dateFormatter.string(from: created))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Button(action: onViewAgain) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, AppColor.secondary)
                    Text("再看一次")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColor.brandGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.14), radius: 20, x: 0, y: 10)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f
    }()
}

private struct StatusPill: View {
    let status: DeskStatus
    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .recruiting: return "招募中"
        case .full: return "已滿"
        case .archived: return "已歸檔"
        }
    }

    private var color: Color {
        switch status {
        case .recruiting: return AppColor.secondary
        case .full: return AppColor.accentOrange
        case .archived: return .gray
        }
    }
}
