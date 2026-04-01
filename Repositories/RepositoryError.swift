import Foundation
import os
import Supabase
import Auth

/// Shared logger for data-layer code (`Repositories/`).
let repositoryLogger = Logger(subsystem: "com.desker.deskerhk", category: "Repository")

/// User-facing API error copy (Cantonese / Mandarin), for Supabase/PostgREST/HTTP responses.
enum APIErrorMessages {
    /// Maps transport and API errors to actionable Chinese messages.
    static func userFacingMessage(for error: Error) -> String {
        if let cfg = error as? DeskerAuthConfigurationError, case .notConfigured = cfg {
            return cfg.errorDescription ?? "請聯繫開發者配置 Supabase"
        }
        if let repo = error as? RepositoryError {
            switch repo {
            case .networkError(let underlying):
                return userFacingMessage(for: underlying)
            case .serverError(let message):
                return message
            case .notAuthenticated:
                return "尚未登入，請重新登入"
            case .notFound:
                return "找不到相關資料"
            case .invalidData:
                return "資料格式不正確，請檢查輸入內容"
            case .unknown:
                return "發生錯誤，請稍後再試"
            }
        }
        if let mapped = mapAuthError(error) {
            return mapped
        }
        if let pg = error as? PostgrestError {
            return mapPostgrest(pg)
        }
        if let http = error as? HTTPError {
            return mapHTTPStatus(http.response.statusCode, bodyData: http.data)
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain || error is URLError {
            return "請檢查網絡連接"
        }
        let desc = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !desc.isEmpty { return desc }
        return "發生錯誤，請稍後再試"
    }

    /// Maps GoTrue / ``AuthError`` (OTP、限流等) to friendly Chinese.
    private static func mapAuthError(_ error: Error) -> String? {
        let e: AuthError? = (error as? AuthError) ?? {
            if let repo = error as? RepositoryError, case .networkError(let u) = repo {
                return u as? AuthError
            }
            return nil
        }()
        guard let authErr = e else { return nil }
        switch authErr {
        case .sessionMissing:
            return "尚未登入，請重新登入"
        case .weakPassword(let message, _):
            let t = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "密碼強度不足，請加強後再試" : t
        case .api(_, let code, _, _):
            if code == .overRequestRateLimit || code == .overEmailSendRateLimit || code == .overSMSSendRateLimit {
                return "請稍後再試"
            }
            if code == .otpExpired {
                return "驗證碼已過期，請重新獲取"
            }
            if code == .invalidCredentials {
                let m = authErr.message.lowercased()
                if m.contains("otp") || m.contains("token") || m.contains("code") || m.contains("sms") || m.contains("phone") {
                    return "驗證碼錯誤"
                }
                return "登入資料不正確，請檢查後再試"
            }
            return nil
        case .pkceGrantCodeExchange, .implicitGrantRedirect, .jwtVerificationFailed:
            return nil
        case .missingExpClaim, .malformedJWT, .invalidRedirectScheme, .missingURL:
            return nil
        }
    }

    private static func mapHTTPStatus(_ code: Int, bodyData: Data) -> String {
        if let pg = try? JSONDecoder().decode(PostgrestError.self, from: bodyData) {
            return mapPostgrest(pg)
        }
        switch code {
        case 400:
            return "資料格式不正確，請檢查輸入內容"
        case 401:
            return "登入已過期，請重新登入"
        case 403:
            return "沒有權限執行此操作"
        case 404:
            return "找不到相關資料"
        case 409:
            return "資料已存在或衝突，請修改後再試"
        case 429:
            return "請稍後再試"
        case 500...599:
            return "伺服器暫時無法處理，請稍後再試"
        default:
            return "網絡錯誤，請稍後再試"
        }
    }

    private static func mapPostgrest(_ pg: PostgrestError) -> String {
        let code = pg.code ?? ""
        let msg = pg.message.lowercased()
        if code == "PGRST116" || msg.contains("0 rows") || msg.contains("no rows") {
            return "找不到相關資料"
        }
        if code == "23505" || msg.contains("duplicate") || msg.contains("unique") {
            return "此資料已存在，請使用其他內容"
        }
        if code.hasPrefix("23") || msg.contains("violates foreign key") {
            return "資料關聯無效，請重新整理後再試"
        }
        if !pg.message.isEmpty { return pg.message }
        return "資料錯誤，請檢查輸入後再試"
    }
}

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
        if let pg = error as? PostgrestError {
            let code = pg.code ?? ""
            let msg = pg.message.lowercased()
            if code == "PGRST116" || msg.contains("0 rows") || msg.contains("no rows") {
                repositoryLogger.error("\(context): not found (PostgREST)")
                return .notFound
            }
        }
        if let http = error as? HTTPError, http.response.statusCode == 404 {
            repositoryLogger.error("\(context): not found (HTTP 404)")
            return .notFound
        }
        repositoryLogger.error("\(context): \(error.localizedDescription)")
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return .networkError(error)
        }
        return .networkError(error)
    }
}
