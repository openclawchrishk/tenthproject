import SwiftUI

/// Swipe-style card for Explore: hero gradient, pitch, founder, industry chips, recruitment progress, Apply.
struct DeskCardView: View {
    let desk: Desk
    let founder: UserProfile?
    let onViewAgain: () -> Void

    private var memberCap: Int {
        max(1, desk.memberLimit)
    }

    private var filledSlots: Int {
        min(desk.currentMemberCount, memberCap)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            deskHero

            VStack(alignment: .leading, spacing: CardChrome.padding) {
                if let founder {
                    HStack(alignment: .center, spacing: 14) {
                        FounderAvatar(urlString: founder.avatarUrl)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("創辦人")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColor.gold)
                            HStack(spacing: 6) {
                                Text(founder.displayName.isEmpty ? "—" : founder.displayName)
                                    .font(.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                if let v = founder.verificationBadgeStyle {
                                    VerificationBadgeView(style: v)
                                }
                            }
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("招募進度", systemImage: "person.3.sequence")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.primary)
                        Spacer()
                        StatusPill(status: desk.status)
                    }

                    recruitmentDots

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(desk.currentMemberCount)/\(memberCap) 人")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            if let created = desk.createdAt {
                                Text(Self.dateFormatter.string(from: created))
                                    .font(.caption)
                                    .foregroundStyle(AppColor.textTertiary)
                            }
                        }
                        GeometryReader { geo in
                            let w = geo.size.width
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColor.surfaceElevated)
                                Capsule()
                                    .fill(AppColor.brandGradient)
                                    .frame(width: max(8, w * CGFloat(filledSlots) / CGFloat(memberCap)))
                            }
                        }
                        .frame(height: 8)
                    }

                    if !desk.recruitingRoles.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("招募角色")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColor.gold)
                            ForEach(desk.recruitingRoles) { role in
                                HStack {
                                    Text(role.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppColor.textPrimary)
                                    Spacer()
                                    Text("×\(role.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    NavigationLink {
                        DeskDetailView(deskId: desk.id)
                    } label: {
                        Text("申請加入")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [AppColor.primary, AppColor.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .deskerButtonShadow()

                    Button(action: onViewAgain) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.caption)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(AppColor.primary, AppColor.gold)
                            Text("換一張")
                        }
                        .font(.headline)
                        .foregroundStyle(AppColor.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColor.primary, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(CardChrome.padding)
        }
        .background(
            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 6)
        )
    }

    private var deskHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    AppColor.primary,
                    Color(hex: "5B4B9A"),
                    AppColor.secondary,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                let dotColor = Color.white.opacity(0.12)
                let step: CGFloat = 18
                var x: CGFloat = 0
                while x < size.width + step {
                    var y: CGFloat = 0
                    while y < size.height + step {
                        let rect = CGRect(x: x, y: y, width: 3, height: 3)
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        y += step
                    }
                    x += step
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "briefcase.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                    Text("Desk")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.gold.opacity(0.95))
                    Spacer()
                }

                Text(desk.name.trimmingCharacters(in: .whitespacesAndNewlines).deskerTruncated(maxLength: 20))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

                Text(desk.pitch.trimmingCharacters(in: .whitespacesAndNewlines).deskerTruncated(maxLength: 100))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !desk.industryTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            let visible = Array(desk.industryTags.prefix(3))
                            let more = max(0, desk.industryTags.count - 3)
                            ForEach(visible, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.22))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                            }
                            if more > 0 {
                                Text("+\(more) 更多")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.18))
                                    .foregroundStyle(AppColor.gold)
                                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(CardChrome.padding)
            .padding(.bottom, 4)
        }
        .frame(minHeight: 168)
        .frame(maxWidth: .infinity)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: CardChrome.cornerRadiusLarge,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: CardChrome.cornerRadiusLarge,
                style: .continuous
            )
        )
    }

    private var recruitmentDots: some View {
        let show = min(memberCap, 10)
        let filled = min(filledSlots, show)
        return HStack(spacing: 6) {
            ForEach(0..<show, id: \.self) { i in
                Circle()
                    .fill(i < filled ? AppColor.primary : AppColor.surfaceElevated)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(AppColor.textTertiary.opacity(0.4), lineWidth: i < filled ? 0 : 1)
                    )
            }
            if memberCap > 10 {
                Text("…")
                    .font(.caption.bold())
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
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
                            .tint(AppColor.primary)
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColor.gold.opacity(0.55), lineWidth: 2))
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 52))
            .symbolRenderingMode(.palette)
            .foregroundStyle(AppColor.primary, AppColor.gold.opacity(0.6))
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
        case .full: return AppColor.warning
        case .archived: return AppColor.textSecondary
        }
    }
}
