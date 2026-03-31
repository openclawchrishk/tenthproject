import SwiftUI

#if os(iOS)
import UIKit

/// UIKit share sheet bridge.
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#else

struct ShareSheetView: View {
    let items: [Any]

    var body: some View {
        Text("分享")
            .padding()
    }
}

#endif
