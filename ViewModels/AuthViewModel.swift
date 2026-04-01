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

    /// Inline validation (shown under fields + red border).
    @Published var fieldErrorEmail: String?
    @Published var fieldErrorPassword: String?
    @Published var fieldErrorDisplayName: String?
    @Published var fieldErrorConfirmPassword: String?

    /// Increment to trigger shake on the form when validation fails.
    @Published var validationShakeTick = 0

    @Published var showEmailNotRegisteredPrompt = false
    @Published var showEmailAlreadyRegisteredPrompt = false
    @Published var needsEmailConfirmation = false

    private let authRepository: AuthRepository

    init(auth: AuthRepository) {
        self.authRepository = auth
    }

    func signInWithEmail() async {
        clearSignInFieldErrors()
        errorMessage = nil
        showEmailNotRegisteredPrompt = false
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            fieldErrorEmail = "請輸入電郵地址"
            bumpShake()
            return
        }
        guard Self.isValidEmail(trimmed) else {
            fieldErrorEmail = "請輸入有效的電郵地址"
            bumpShake()
            return
        }
        guard !password.isEmpty else {
            fieldErrorPassword = "請輸入密碼"
            bumpShake()
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

    private func clearSignInFieldErrors() {
        fieldErrorEmail = nil
        fieldErrorPassword = nil
    }

    private func clearSignUpFieldErrors() {
        fieldErrorEmail = nil
        fieldErrorPassword = nil
        fieldErrorDisplayName = nil
        fieldErrorConfirmPassword = nil
    }

    private func bumpShake() {
        validationShakeTick += 1
    }

    private func handleSignInError(_ error: Error, normalizedEmail: String) async {
        if let authErr = error as? AuthError, authErr.errorCode == .invalidCredentials {
            do {
                let registered = try await authRepository.checkEmailRegistered(email: normalizedEmail)
                if registered {
                    fieldErrorPassword = "電郵或密碼不正確，請檢查後再試"
                    bumpShake()
                } else {
                    errorMessage = nil
                    showEmailNotRegisteredPrompt = true
                }
            } catch {
                fieldErrorPassword = "電郵或密碼不正確，請檢查後再試"
                bumpShake()
            }
            return
        }
        errorMessage = Self.mapGenericAuthError(error)
        bumpShake()
    }

    func signUpWithEmail() async {
        clearSignUpFieldErrors()
        errorMessage = nil
        showEmailAlreadyRegisteredPrompt = false
        needsEmailConfirmation = false
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            fieldErrorEmail = "請輸入電郵地址"
            bumpShake()
            return
        }
        guard Self.isValidEmail(trimmedEmail) else {
            fieldErrorEmail = "請輸入有效的電郵地址"
            bumpShake()
            return
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            fieldErrorDisplayName = "請輸入顯示名稱"
            bumpShake()
            return
        }
        guard name.count <= ProfileFieldValidation.displayNameMaxLength else {
            fieldErrorDisplayName = "顯示名稱最多 \(ProfileFieldValidation.displayNameMaxLength) 字"
            bumpShake()
            return
        }
        guard password.count >= 8 else {
            fieldErrorPassword = "密碼至少需要 8 個字元"
            bumpShake()
            return
        }
        guard ProfileFieldValidation.PasswordStrength.evaluate(password).meetsSignUpMinimum else {
            fieldErrorPassword = "密碼強度太弱，請加入英文字母、數字或符號"
            bumpShake()
            return
        }
        guard password == confirmPassword else {
            fieldErrorConfirmPassword = "兩次輸入嘅密碼不一致"
            bumpShake()
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
                DeskerAnalytics.track(.userSignUp)
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
            bumpShake()
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
            if case .weakPassword(let msg, _) = authErr {
                let t = msg.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? "密碼強度不足，請加強密碼後再試" : t
            }
            switch authErr.errorCode {
            case .invalidCredentials:
                return "電郵或密碼不正確，請檢查後再試"
            case .emailExists, .userAlreadyExists:
                return "此電郵已被註冊，請直接登入"
            case .userNotFound:
                return "此電郵未註冊"
            case .overRequestRateLimit, .overEmailSendRateLimit, .overSMSSendRateLimit:
                return "請稍後再試"
            default:
                break
            }
        }
        if error is URLError || (error as NSError).domain == NSURLErrorDomain {
            return "請檢查網絡連接"
        }
        return "請檢查網絡連接"
    }
}
