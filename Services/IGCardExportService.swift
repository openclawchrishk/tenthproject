import SwiftUI

#if os(iOS)
import UIKit
#endif

#if os(iOS) && canImport(Photos)
import Photos
#endif

/// Renders 1080×1350 story cards (PRD §11) using SwiftUI → `ImageRenderer`.
@MainActor
enum IGCardExportService {
    static let exportSize = CGSize(width: 1080, height: 1350)

    #if os(iOS)
    static func renderProfileCard(user: UserProfile) -> UIImage? {
        let view = ProfileStoryCardView(user: user)
            .frame(width: exportSize.width, height: exportSize.height)
        return renderImage(view)
    }

    static func renderDeskRecruitmentCard(desk: Desk, founderName: String) -> UIImage? {
        let view = DeskRecruitmentStoryCardView(desk: desk, founderName: founderName)
            .frame(width: exportSize.width, height: exportSize.height)
        return renderImage(view)
    }

    private static func renderImage<V: View>(_ view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
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
    static func renderProfileCard(user: UserProfile) -> Any? { nil }
    static func renderDeskRecruitmentCard(desk: Desk, founderName: String) -> Any? { nil }
    static func saveToPhotoLibrary(_ image: Any) async throws {}
    #endif
}

// MARK: - Story layouts (Canvas-style branding)

private struct ProfileStoryCardView: View {
    let user: UserProfile

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0A1628"), Color(hex: "1A3A52")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("DeskerHK")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if user.isPremium {
                        Text("PREMIUM")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.9))
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }
                Text(user.displayName)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(user.role.localizedName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                if !user.industryTags.isEmpty {
                    Text(user.industryTags.prefix(4).joined(separator: " · "))
                        .font(.system(size: 26))
                        .foregroundStyle(AppColor.secondary)
                }
                Spacer()
                Text("desker.hk")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.secondary)
            }
            .padding(56)
        }
        .frame(width: IGCardExportService.exportSize.width, height: IGCardExportService.exportSize.height)
    }
}

private struct DeskRecruitmentStoryCardView: View {
    let desk: Desk
    let founderName: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1C1C1E"), Color(hex: "007AFF").opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 20) {
                Text("組隊招募")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(AppColor.secondary)
                Text(desk.name)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text(desk.pitch)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(5)
                Spacer()
                HStack {
                    Text("創辦人：\(founderName)")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
                Text(PublicLinks.deskURL(deskId: desk.id).absoluteString)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppColor.secondary)
            }
            .padding(56)
        }
        .frame(width: IGCardExportService.exportSize.width, height: IGCardExportService.exportSize.height)
    }
}
