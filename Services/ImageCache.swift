import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// In-memory image bytes cache with deduplicated network loads. Decoded `UIImage` lives in `NSCache` on iOS for fast reuse.
actor ImageCache {
    static let shared = ImageCache()

    /// Raw bytes — works across targets; avoids duplicate downloads.
    private let dataCache = NSCache<NSString, NSData>()

    #if canImport(UIKit)
    /// Decoded images (user-requested `NSCache<NSString, UIImage>` pattern).
    private let imageCache = NSCache<NSString, UIImage>()
    #endif

    private init() {
        dataCache.countLimit = 300
        dataCache.totalCostLimit = 80 * 1024 * 1024
        #if canImport(UIKit)
        imageCache.countLimit = 200
        imageCache.totalCostLimit = 60 * 1024 * 1024
        #endif
    }

    /// Loads image bytes, using cache when possible. Respects `Task` cancellation.
    func imageData(for url: URL) async throws -> Data {
        let key = url.absoluteString as NSString
        if let cached = dataCache.object(forKey: key) as Data? {
            return cached
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        dataCache.setObject(data as NSData, forKey: key, cost: data.count)
        return data
    }

    #if canImport(UIKit)
    /// Returns a decoded `UIImage` from memory cache or after download.
    func uiImage(for url: URL) async throws -> UIImage? {
        let key = url.absoluteString as NSString
        if let img = imageCache.object(forKey: key) {
            return img
        }
        let data = try await imageData(for: url)
        try Task.checkCancellation()
        guard let img = UIImage(data: data) else { return nil }
        imageCache.setObject(img, forKey: key, cost: data.count)
        return img
    }
    #endif
}
