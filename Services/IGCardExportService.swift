import SwiftUI

#if os(iOS)
import UIKit
#endif

#if os(iOS) && canImport(Photos)
import Photos
#endif

import os

private let igCardLog = Logger(subsystem: "hk.desker", category: "IGCardExport")

/// Renders 1080×1350 story cards using SwiftUI `ImageRenderer` (pixel-aligned at scale 1.0).
@MainActor
enum IGCardExportService {
    static let exportSize = CGSize(width: 1080, height: 1350)

    #if os(iOS)
    static func renderProfileCard(user: UserProfile, avatarImage: UIImage?) -> UIImage? {
        let view = ProfileStoryCardView(user: user, avatarImage: avatarImage)
            .frame(width: exportSize.width, height: exportSize.height)
        return renderImage(view)
    }

    static func renderDeskRecruitmentCard(desk: Desk, founder: UserProfile, founderAvatar: UIImage?) -> UIImage? {
        let view = DeskRecruitmentStoryCardView(desk: desk, founder: founder, founderAvatar: founderAvatar)
            .frame(width: exportSize.width, height: exportSize.height)
        return renderImage(view)
    }

    /// Loads an image from a remote URL for embedding in export cards (async).
    static func loadUIImage(from url: URL) async -> UIImage? {
        do {
            return try await ImageCache.shared.uiImage(for: url)
        } catch {
            igCardLog.error("Avatar load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func renderImage<V: View>(_ view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        guard let image = renderer.uiImage else {
            igCardLog.error("ImageRenderer returned nil")
            return nil
        }
        /// Optional UIGraphicsImageRenderer pass to normalize format (RGBA, correct scale).
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let out = UIGraphicsImageRenderer(size: exportSize, format: format)
        return out.image { _ in
            image.draw(in: CGRect(origin: .zero, size: exportSize))
        }
    }

    #if canImport(Photos)
    static func saveToPhotoLibrary(_ image: UIImage) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
    #else
    static func saveToPhotoLibrary(_ image: UIImage) async throws {}
    #endif
    #else
    static func renderProfileCard(user: UserProfile, avatarImage: Any?) -> Any? { nil }
    static func renderDeskRecruitmentCard(desk: Desk, founder: UserProfile, founderAvatar: Any?) -> Any? { nil }
    static func loadUIImage(from url: URL) async -> Any? { nil }
    static func saveToPhotoLibrary(_ image: Any) async throws {}
    #endif
}

#if os(iOS)

// MARK: - Profile card (1080×1350)

private struct ProfileStoryCardView: View {
    let user: UserProfile
    let avatarImage: UIImage?

    private var displayName: String {
        let n = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Desker" : n.deskerTruncated(maxLength: 20)
    }

    private var bioLine: String {
        let raw = (user.bio ?? user.detailedBio ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.deskerTruncated(maxLength: 100)
    }

    private var tagStrings: [String] {
        Array(Set(user.industryTags + user.interestTags + user.skills)).sorted()
    }

    private var visibleTags: [String] { Array(tagStrings.prefix(3)) }
    private var tagOverflow: Int { max(0, tagStrings.count - 3) }

    private var profileURLString: String {
        PublicLinks.profilePublicURL(for: user).absoluteString
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2D346D"), Color(hex: "5856D6")],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                let dot = Color.white.opacity(0.08)
                let step: CGFloat = 22
                for x in stride(from: 0, to: size.width + step, by: step) {
                    for y in stride(from: 0, to: size.height + step, by: step) {
                        let r = CGRect(x: x, y: y, width: 2, height: 2)
                        context.fill(Path(ellipseIn: r), with: .color(dot))
                    }
                }
            }

            VStack(spacing: 0) {
                headerBrand
                    .padding(.top, 44)
                    .padding(.horizontal, 48)

                Spacer(minLength: 20)

                avatarSection

                Text(displayName)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                rolePill
                    .padding(.top, 12)

                Text(regionLanguagesLine)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)

                if !bioLine.isEmpty {
                    Text(bioLine)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 44)
                        .padding(.top, 16)
                }

                tagChipsRow
                    .padding(.top, 18)

                needsSection
                    .padding(.top, 22)

                Spacer(minLength: 24)

                footerBrand
                    .padding(.bottom, 48)
            }
        }
        .frame(width: IGCardExportService.exportSize.width, height: IGCardExportService.exportSize.height)
    }

    private var headerBrand: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AppColor.gold, lineWidth: 2)
                    .frame(width: 52, height: 52)
                Text("DH")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.gold)
            }
            Text("Desker HK")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.gold)
            Spacer()
        }
    }

    private var avatarSection: some View {
        ZStack {
            if let img = avatarImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 200, height: 200)
                    Text(initials(from: user.displayName))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            Circle()
                .stroke(user.isPremium ? AppColor.gold : Color.white.opacity(0.35), lineWidth: user.isPremium ? 6 : 3)
                .frame(width: 200, height: 200)
        }
    }

    private var rolePill: some View {
        Text(user.role.localizedName)
            .font(.system(size: 24, weight: .bold))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(rolePillBackground)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var rolePillBackground: Color {
        switch user.role {
        case .investor: return AppColor.gold.opacity(0.35)
        case .mentor: return AppColor.teal.opacity(0.4)
        default: return AppColor.primary.opacity(0.55)
        }
    }

    private var regionLanguagesLine: String {
        let langs = user.languages.joined(separator: " · ")
        return "\(user.region)  ·  \(langs)"
    }

    private var tagChipsRow: some View {
        Group {
            if tagStrings.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(visibleTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        if tagOverflow > 0 {
                            Text("+\(tagOverflow) 更多")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppColor.gold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var needsSection: some View {
        Group {
            if user.needs.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 12) {
                    Text("我正在尋找：")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColor.gold)
                    let shown = Array(user.needs.prefix(6))
                    let extra = max(0, user.needs.count - shown.count)
                    FlowTagWrap(tags: shown, extraCount: extra)
                }
                .padding(.horizontal, 36)
            }
        }
    }

    private var footerBrand: some View {
        VStack(spacing: 8) {
            Text(profileURLString)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("Desker HK")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.gold.opacity(0.95))
        }
        .padding(.horizontal, 36)
    }

    private func initials(from name: String) -> String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = t.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        let s = String(t.prefix(2))
        return s.isEmpty ? "?" : s.uppercased()
    }
}

// MARK: - Desk card (1080×1350)

private struct DeskRecruitmentStoryCardView: View {
    let desk: Desk
    let founder: UserProfile
    let founderAvatar: UIImage?

    private var deskTitle: String {
        desk.name.trimmingCharacters(in: .whitespacesAndNewlines).deskerTruncated(maxLength: 20)
    }

    private var pitchLine: String {
        desk.pitch.trimmingCharacters(in: .whitespacesAndNewlines).deskerTruncated(maxLength: 100)
    }

    private var industryVisible: [String] { Array(desk.industryTags.prefix(3)) }
    private var industryOverflow: Int { max(0, desk.industryTags.count - 3) }

    private var founderName: String {
        let n = founder.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "創辦人" : n.deskerTruncated(maxLength: 20)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "5856D6"), Color(hex: "2D346D")],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                let dot = Color.white.opacity(0.07)
                let step: CGFloat = 24
                for x in stride(from: 0, to: size.width + step, by: step) {
                    for y in stride(from: 0, to: size.height + step, by: step) {
                        let r = CGRect(x: x + 4, y: y, width: 2, height: 2)
                        context.fill(Path(ellipseIn: r), with: .color(dot))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("正在招募")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(AppColor.gold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 48)
                .padding(.horizontal, 48)

                Text(deskTitle)
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 48)
                    .padding(.top, 28)

                Text(pitchLine)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(4)
                    .padding(.horizontal, 48)
                    .padding(.top, 14)

                industryRow
                    .padding(.horizontal, 48)
                    .padding(.top, 20)

                recruitingBlock
                    .padding(.horizontal, 48)
                    .padding(.top, 22)

                Spacer(minLength: 20)

                founderRow
                    .padding(.horizontal, 48)
                    .padding(.bottom, 36)

                footerDesk
                    .padding(.horizontal, 48)
                    .padding(.bottom, 48)
            }
        }
        .frame(width: IGCardExportService.exportSize.width, height: IGCardExportService.exportSize.height)
    }

    private var industryRow: some View {
        Group {
            if desk.industryTags.isEmpty {
                EmptyView()
            } else {
                HStack(spacing: 10) {
                    ForEach(industryVisible, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    if industryOverflow > 0 {
                        Text("+\(industryOverflow) 更多")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppColor.gold)
                    }
                }
            }
        }
    }

    private var recruitingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("招募角色")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            if desk.recruitingRoles.isEmpty {
                Text(desk.skillsSummary.isEmpty ? "—" : desk.skillsSummary.deskerTruncated(maxLength: 120))
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white.opacity(0.88))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(desk.recruitingRoles) { role in
                        Text("· \(role.title) ×\(role.count)")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var founderRow: some View {
        HStack(spacing: 16) {
            founderAvatarView
            VStack(alignment: .leading, spacing: 8) {
                Text("創辦人")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColor.gold)
                HStack(spacing: 10) {
                    Text(founderName)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    if founder.verificationBadgeStyle != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 26))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppColor.gold, .white.opacity(0.9))
                    }
                }
            }
            Spacer()
        }
    }

    private var founderAvatarView: some View {
        ZStack {
            if let img = founderAvatar {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 96, height: 96)
                    Text(initials(from: founder.displayName))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Circle()
                .stroke(AppColor.gold.opacity(0.65), lineWidth: 3)
                .frame(width: 96, height: 96)
        }
    }

    private var footerDesk: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(PublicLinks.deskURL(deskId: desk.id).absoluteString)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            Text("Desker HK")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.gold.opacity(0.95))
        }
    }

    private func initials(from name: String) -> String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = t.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        let s = String(t.prefix(2))
        return s.isEmpty ? "?" : s.uppercased()
    }
}

// MARK: - Needs chips (simple wrap for export)

private struct FlowTagWrap: View {
    let tags: [String]
    let extraCount: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColor.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColor.gold.opacity(0.92))
                        .clipShape(Capsule())
                }
                if extraCount > 0 {
                    Text("+\(extraCount)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#endif
