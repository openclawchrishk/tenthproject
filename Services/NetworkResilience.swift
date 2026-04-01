import Foundation

/// Retry transient network failures and align with URL session timeouts (see ``SupabaseManager``).
enum NetworkResilience {
    /// Maximum attempts including the first try.
    private static let defaultMaxAttempts = 3

    /// Base delay between retries (attempt N uses `baseMs * N`).
    private static let baseRetryNanoseconds: UInt64 = 350_000_000

    static func isTransientNetworkError(_ error: Error) -> Bool {
        if let url = error as? URLError {
            switch url.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                 .internationalRoamingOff, .callIsActive, .dataNotAllowed:
                return true
            default:
                return false
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet,
                 NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed,
                 NSURLErrorDataNotAllowed:
                return true
            default:
                return false
            }
        }
        return false
    }

    /// Retries when `isTransientNetworkError` is true; otherwise rethrows immediately.
    static func withRetry<T>(
        maxAttempts: Int = defaultMaxAttempts,
        _ operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt >= maxAttempts || !isTransientNetworkError(error) {
                    throw error
                }
                let delay = baseRetryNanoseconds * UInt64(attempt)
                try await Task.sleep(nanoseconds: delay)
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}
