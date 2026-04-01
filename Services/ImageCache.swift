import Foundation

#if canImport(UIKit)
import UIKit
import ImageIO
#endif

/// In-memory image bytes cache with deduplicated network loads. Decoded `UIImage` lives in `NSCache` on iOS for fast reuse.
actor ImageCache {
    static let shared = ImageCache()

    private nonisolated static let urlSession: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 45
        c.timeoutIntervalForResource = 120
        c.waitsForConnectivity = true
        c.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: c)
    }()

    /// Raw bytes — works across targets; avoids duplicate downloads.
    private let dataCache = NSCache<NSString, NSData>()

    #if canImport(UIKit)
    /// Decoded images (user-requested `NSCache<NSString, UIImage>` pattern).
    private let imageCache = NSCache<NSString, UIImage>()
    #endif

    /// Clears decoded and raw byte caches (e.g. after sign-out).
    func removeAll() {
        dataCache.removeAllObjects()
        #if canImport(UIKit)
        imageCache.removeAllObjects()
        #endif
    }

    private init() {
        dataCache.countLimit = 300
        dataCache.totalCostLimit = 80 * 1024 * 1024
        #if canImport(UIKit)
        imageCache.countLimit = 200
        imageCache.totalCostLimit = 60 * 1024 * 1024
        #endif
    }

    /// Loads image bytes, using cache when possible. Respects `Task` cancellation; retries once on transient URL errors.
    func imageData(for url: URL) async throws -> Data {
        let key = url.absoluteString as NSString
        if let cached = dataCache.object(forKey: key) as Data? {
            return cached
        }
        do {
            let data = try await loadImageDataOnce(from: url)
            dataCache.setObject(data as NSData, forKey: key, cost: data.count)
            return data
        } catch {
            if Self.shouldRetryImageLoad(error) {
                try await Task.sleep(nanoseconds: 400_000_000)
                try Task.checkCancellation()
                let data = try await loadImageDataOnce(from: url)
                dataCache.setObject(data as NSData, forKey: key, cost: data.count)
                return data
            }
            throw error
        }
    }

    private func loadImageDataOnce(from url: URL) async throws -> Data {
        let (data, response) = try await Self.urlSession.data(from: url)
        try Task.checkCancellation()
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private nonisolated static func shouldRetryImageLoad(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet:
                return true
            default:
                break
            }
        }
        if let u = error as? URLError {
            switch u.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet:
                return true
            default:
                break
            }
        }
        return false
    }

    #if canImport(UIKit)
    /// Returns a decoded `UIImage` from memory cache or after download.
    /// When `maxPixelDimension` is set, decodes a downsampled bitmap (lower memory / GPU cost for list avatars).
    func uiImage(for url: URL, maxPixelDimension: CGFloat? = nil) async throws -> UIImage? {
        let cacheKey = Self.imageCacheKey(url: url, maxPixelDimension: maxPixelDimension) as NSString
        if let img = imageCache.object(forKey: cacheKey) {
            return img
        }
        let data = try await imageData(for: url)
        try Task.checkCancellation()
        let img: UIImage?
        if let max = maxPixelDimension, max > 0 {
            img = Self.downsampleImage(data: data, maxPixelDimension: max)
        } else {
            img = UIImage(data: data)
        }
        guard let img else { return nil }
        let cost = img.pngData()?.count ?? data.count
        imageCache.setObject(img, forKey: cacheKey, cost: cost)
        return img
    }

    private static func imageCacheKey(url: URL, maxPixelDimension: CGFloat?) -> String {
        if let m = maxPixelDimension, m > 0 {
            return url.absoluteString + "|thumb:\(Int(m))"
        }
        return url.absoluteString
    }

    /// ImageIO thumbnail decode — avoids full-resolution `UIImage` decode for large photos.
    private static func downsampleImage(data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        let maxPx = Int(max(1, maxPixelDimension))
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPx,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }
    #endif
}
