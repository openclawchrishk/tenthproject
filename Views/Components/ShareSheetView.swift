import SwiftUI

#if os(iOS)
import UIKit

/// UIKit share sheet bridge — pass `URL` (https, `file://` exports), `String`, or `UIImage`; combine for IG card + link.
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Copy link, system share (`UIActivityViewController`), optional IG card generation.
struct DeskerShareOptionsSheet: View {
    let title: String
    let url: URL
    /// When set, shows「產生 IG 卡並分享」and passes image + URL to the activity sheet.
    var onBuildIGCardShareItems: (() async -> [Any]?)?

    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var activityItems: [Any] = []
    @State private var igBusy = false
    @State private var banner: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(url.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .textSelection(.enabled)
                } header: {
                    Text("連結")
                }

                Section {
                    Button {
                        UIPasteboard.general.url = url
                        HapticFeedback.success()
                        banner = "已複製到剪貼簿"
                    } label: {
                        Label("複製連結", systemImage: "doc.on.doc")
                    }

                    Button {
                        activityItems = [url]
                        showSystemShare = true
                        HapticFeedback.light()
                    } label: {
                        Label("系統分享…", systemImage: "square.and.arrow.up")
                    }

                    if onBuildIGCardShareItems != nil {
                        Button {
                            Task { await runIGExport() }
                        } label: {
                            HStack {
                                Label("產生 IG 卡並分享", systemImage: "photo.on.rectangle.angled")
                                if igBusy {
                                    Spacer()
                                    ProgressView()
                                        .tint(AppColor.primary)
                                }
                            }
                        }
                        .disabled(igBusy)
                    }
                }

                if let banner {
                    Section {
                        Text(banner)
                            .font(.footnote)
                            .foregroundStyle(banner.contains("失敗") ? AppColor.error : AppColor.textSecondary)
                    }
                }
            }
            .navigationTitle(title)
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .deskerSheetSpringContent()
        }
        .sheet(isPresented: $showSystemShare) {
            ShareSheetView(items: activityItems)
        }
    }

    private func runIGExport() async {
        guard let builder = onBuildIGCardShareItems else { return }
        igBusy = true
        banner = nil
        defer { igBusy = false }
        if let items = await builder(), !items.isEmpty {
            activityItems = items
            showSystemShare = true
            HapticFeedback.success()
        } else {
            banner = "無法產生圖片"
            HapticFeedback.error()
        }
    }
}

#else

struct ShareSheetView: View {
    let items: [Any]

    var body: some View {
        Text("分享")
            .padding()
    }
}

struct DeskerShareOptionsSheet: View {
    let title: String
    let url: URL
    var onBuildIGCardShareItems: (() async -> [Any]?)?

    var body: some View {
        Text("分享")
            .padding()
    }
}

#endif
