import Foundation

/// SwiftUI `.refreshable` / task cancellation — do not treat as failures.
enum DeskerCancellation {
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return true }
        if let u = error as? URLError, u.code == .cancelled { return true }
        return false
    }
}

/// Network resilience helpers for retry logic with exponential backoff
enum NetworkResilience {
    /// Maximum number of retry attempts
    static let maxAttempts = 3
    
    /// Initial delay before first retry (in seconds)
    static let initialBackoffDelay: Double = 0.5
    
    /// Execute a network operation with retry logic
    /// - Parameters:
    ///   - operation: The async operation to perform
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - backoffDelay: Initial backoff delay in seconds (default: 0.5)
    /// - Returns: The result of the operation
    /// - Throws: The last error if all attempts fail
    static func withRetry<T>(
        maxAttempts: Int = Self.maxAttempts,
        backoffDelay: Double = Self.initialBackoffDelay,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = backoffDelay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if DeskerCancellation.isCancellation(error) { throw error }

                // Don't retry on last attempt
                if attempt < maxAttempts {
                    // Check if error is retryable (network-related)
                    if isRetryableError(error) {
                        // Exponential backoff
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        delay *= 2 // Double the delay for next retry
                    } else {
                        // Non-retryable error, throw immediately
                        throw error
                    }
                }
            }
        }
        
        throw lastError ?? RepositoryError.unknown
    }
    
    /// Check if an error is retryable
    private static func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Retry on network-related errors
        let retryableCodes: [Int] = [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorInternationalRoamingOff,
            NSURLErrorSecureConnectionFailed
        ]
        
        return retryableCodes.contains(nsError.code)
    }
}
