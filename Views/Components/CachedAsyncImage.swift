import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// Remote image view using `ImageCache` and task cancellation when `url` changes.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (CachedAsyncImagePhase) -> Content

    @State private var phase: CachedAsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url?.absoluteString) {
                await load()
            }
    }

    private func load() async {
        guard let url else {
            await MainActor.run { phase = .failure }
            return
        }
        await MainActor.run { phase = .empty }
        do {
            #if canImport(UIKit)
            if let ui = try await ImageCache.shared.uiImage(for: url) {
                try Task.checkCancellation()
                let img = Image(uiImage: ui)
                await MainActor.run { phase = .success(img) }
            } else {
                await MainActor.run { phase = .failure }
            }
            #elseif canImport(AppKit)
            let data = try await ImageCache.shared.imageData(for: url)
            try Task.checkCancellation()
            if let ns = NSImage(data: data) {
                await MainActor.run { phase = .success(Image(nsImage: ns)) }
            } else {
                await MainActor.run { phase = .failure }
            }
            #else
            _ = try await ImageCache.shared.imageData(for: url)
            await MainActor.run { phase = .failure }
            #endif
        } catch is CancellationError {
        } catch {
            await MainActor.run { phase = .failure }
        }
    }
}

enum CachedAsyncImagePhase {
    case empty
    case success(Image)
    case failure
}
