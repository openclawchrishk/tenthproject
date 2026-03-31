import SwiftUI

/// Swipe-style card for Explore: pitch, industry, founder, roles, member count.
struct DeskCardView: View {
    let desk: Desk
    let founder: UserProfile?
    let onViewAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CardChrome.sectionSpacing / 2) {
            HStack {
                Image(systemName: "briefcase.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColor.primary, AppColor.secondary)
                Text(desk.name)
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                StatusPill(status: desk.status)
            }

            if let founder {
                HStack(alignment: .center, spacing: 12) {
                    FounderAvatar(urlString: founder.avatarUrl)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("創辦人")
                            .font(.caption)
                            .foregroundStyle(AppColor.textSecondary)
                        HStack(spacing: 6) {
                            Text(founder.displayName.isEmpty ? "—" : founder.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.textPrimary)
                            if let v = founder.verificationBadgeStyle {
                                VerificationBadgeView(style: v)
                            }
                        }
                    }
                    Spacer()
                }
            }

            Text(desk.pitch)
                .font(.body)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !desk.industryTags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("產業", systemImage: "tag.fill")
                        .font(.caption.bold())
                        .foregroundStyle(AppColor.secondary)
                    DeskCardTagFlow(tags: desk.industryTags)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("招募角色", systemImage: "person.badge.plus")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.accentOrange)
                if desk.recruitingRoles.isEmpty {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    ForEach(desk.recruitingRoles) { role in
                        HStack {
                            Text(role.title)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("×\(role.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
            }

            HStack {
                Label("\(desk.currentMemberCount)/\(desk.memberLimit) 人", systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.primary)
                Spacer()
                if let created = desk.createdAt {
                    Text(Self.dateFormatter.string(from: created))
                        .font(.caption2)
                        .foregroundStyle(AppColor.textSecondary)
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
        .padding(CardChrome.padding)
        .deskerElevatedCard()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_Hant_HK")
        return f
    }()
}

private struct FounderAvatar: View {
    let urlString: String?

    var body: some View {
        Group {
            if let s = urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
               let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 44))
            .symbolRenderingMode(.palette)
            .foregroundStyle(AppColor.primary, AppColor.secondary)
    }
}

private struct DeskCardTagFlow: View {
    let tags: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColor.secondary.opacity(0.12))
                    .foregroundStyle(AppColor.secondary)
                    .clipShape(Capsule())
            }
        }
    }
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
        case .archived: return AppColor.textSecondary
        }
    }
}
