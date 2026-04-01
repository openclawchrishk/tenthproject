import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var emailExists: Bool?
    @Published var isPasswordResetSent = false

    @Published var showEmailNotRegisteredPrompt = false
    @Published var showEmailAlreadyRegisteredPrompt = false
    @Published var needsEmailConfirmation = false

    private let authRepository: AuthRepository

    init(auth: AuthRepository) {
        self.authRepository = auth
    }

    func signInWithEmail() async {
        errorMessage = nil
        showEmailNotRegisteredPrompt = false
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(trimmed) else {
            errorMessage = "請輸入有效的電郵地址"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "請輸入密碼"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await authRepository.signInWithEmail(email: trimmed, password: password)
            await authRepository.refreshProfile()
        } catch {
            await handleSignInError(error, normalizedEmail: trimmed)
        }
    }

    private func handleSignInError(_ error: Error, normalizedEmail: String) async {
        if let authErr = error as? AuthError, authErr.errorCode == .invalidCredentials {
            do {
                let registered = try await authRepository.checkEmailRegistered(email: normalizedEmail)
                if registered {
                    errorMessage = "密碼錯誤，請重試"
                } else {
                    errorMessage = nil
                    showEmailNotRegisteredPrompt = true
                }
            } catch {
                errorMessage = "密碼錯誤，請重試"
            }
            return
        }
        errorMessage = Self.mapGenericAuthError(error)
    }

    func signUpWithEmail() async {
        errorMessage = nil
        showEmailAlreadyRegisteredPrompt = false
        needsEmailConfirmation = false
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(trimmedEmail) else {
            errorMessage = "請輸入有效的電郵地址"
            return
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "請輸入顯示名稱"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "密碼至少需要 8 個字元"
            return
        }
        guard password == confirmPassword else {
            errorMessage = "兩次輸入嘅密碼不一致"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await authRepository.signUpWithEmail(
                email: trimmedEmail,
                password: password,
                displayName: name
            )
            if response.session != nil {
                await authRepository.refreshProfile()
            } else {
                needsEmailConfirmation = true
            }
        } catch {
            if let authErr = error as? AuthError {
                switch authErr.errorCode {
                case .emailExists, .userAlreadyExists:
                    errorMessage = nil
                    showEmailAlreadyRegisteredPrompt = true
                    return
                default:
                    break
                }
            }
            errorMessage = Self.mapGenericAuthError(error)
        }
    }

    func checkEmailExists(email raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(trimmed) else {
            emailExists = nil
            return
        }
        do {
            emailExists = try await authRepository.checkEmailRegistered(email: trimmed)
        } catch {
            emailExists = nil
        }
    }

    func resetPassword() async {
        errorMessage = nil
        isPasswordResetSent = false
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(trimmed) else {
            errorMessage = "請輸入有效的電郵地址"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await authRepository.resetPassword(email: trimmed)
            isPasswordResetSent = true
        } catch {
            errorMessage = Self.mapGenericAuthError(error)
        }
    }

    static func isValidEmail(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    static func mapGenericAuthError(_ error: Error) -> String {
        if let authErr = error as? AuthError {
            switch authErr.errorCode {
            case .invalidCredentials:
                return "密碼錯誤，請重試"
            case .emailExists, .userAlreadyExists:
                return "此電郵已被註冊"
            case .userNotFound:
                return "此電郵未註冊"
            case .overRequestRateLimit, .overEmailSendRateLimit, .overSMSSendRateLimit:
                return "操作太頻繁，請稍後再試"
            default:
                break
            }
        }
        if error is URLError || (error as NSError).domain == NSURLErrorDomain {
            return "無網絡連接，請檢查網絡設定"
        }
        return error.localizedDescription
    }
}
