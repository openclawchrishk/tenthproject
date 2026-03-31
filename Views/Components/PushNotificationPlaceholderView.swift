import SwiftUI

/// Documents future APNs integration (PRD §12).
struct PushNotificationPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("推播通知", systemImage: "bell.badge.fill")
                .font(.headline)
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppColor.primary, AppColor.secondary)
            Text("正式版將向 Apple 申請推播權限，並透過 APNs 傳送新訊息與 Desk 通知。目前僅使用 App 內通知列表。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.secondaryGroupedSurface, in: RoundedRectangle(cornerRadius: CardChrome.cornerRadius))
    }
}
