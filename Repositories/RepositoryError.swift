import Foundation
import os

/// Shared logger for data-layer code (`Repositories/`).
let repositoryLogger = Logger(subsystem: "com.desker.deskerhk", category: "Repository")

enum RepositoryError: Error {
    case notAuthenticated
    case notFound
    case networkError(Error)
    case invalidData
    case serverError(String)
    case unknown
}

extension RepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "尚未登入"
        case .notFound:
            return "找不到資料"
        case .networkError(let underlying):
            return underlying.localizedDescription
        case .invalidData:
            return "資料格式錯誤"
        case .serverError(let message):
            return message
        case .unknown:
            return "發生未知錯誤"
        }
    }
}

enum RepositoryErrorMapping {
    static func map(_ error: Error, context: String) -> RepositoryError {
        if let r = error as? RepositoryError {
            repositoryLogger.error("\(context): \(String(describing: r))")
            return r
        }
        repositoryLogger.error("\(context): \(error.localizedDescription)")
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return .networkError(error)
        }
        return .networkError(error)
    }
}
