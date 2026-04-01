import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject private var auth: AuthRepository
    @State private var showPhoneLogin = false
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "007AFF"),
                    Color(hex: "5856D6"),
                    Color(hex: "AF52DE")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and branding
                VStack(spacing: 16) {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white)
                        .shadow(radius: 20)

                    Text("Desker HK")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("香港創業社群")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(2)

                    Text("連接創辦人、投資者、創業家")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.bottom, 60)

                Spacer()

                // Login buttons
                VStack(spacing: 16) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.email, .fullName]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .cornerRadius(12)

                    // Phone login
                    Button {
                        showPhoneLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("使用手機號碼登入")
                        }
                        .font(.headline)
                        .foregroundStyle(Color(hex: "007AFF"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(12)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Terms
                Text("登入即表示你同意我們的條款")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 32)
            }

            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .sheet(isPresented: $showPhoneLogin) {
            PhoneLoginView()
                .environmentObject(auth)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorText = "無法獲取 Apple ID 憑證"
                return
            }
            guard let idTokenData = appleIDCredential.identityToken,
                  let idTokenString = String(data: idTokenData, encoding: .utf8) else {
                errorText = "無效的身份權杖"
                return
            }

            isLoading = true
            errorText = nil

            Task {
                do {
                    try await auth.signInWithApple(idToken: idTokenString, nonce: "")
                    // Profile creation is handled by AuthRepository's auth state listener
                } catch {
                    await MainActor.run {
                        errorText = "登入失敗：\(error.localizedDescription)"
                        isLoading = false
                    }
                }
            }

        case .failure(let error):
            errorText = "Apple 登入失敗：\(error.localizedDescription)"
        }
    }
}

struct PhoneLoginView: View {
    @EnvironmentObject private var auth: AuthRepository
    @Environment(\.dismiss) private var dismiss

    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var step: LoginStep = .phoneEntry
    @State private var isLoading = false
    @State private var errorText: String?

    enum LoginStep {
        case phoneEntry
        case otpVerification
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 32) {
                    if step == .phoneEntry {
                        phoneEntryView
                    } else {
                        otpVerificationView
                    }
                }
                .padding()

                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
            .navigationTitle(step == .phoneEntry ? "手機登入" : "驗證碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var phoneEntryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColor.primary)

                Text("輸入你嘅手機號碼")
                    .font(.title2.bold())

                Text("我哋會發送驗證碼到你嘅電話")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            VStack(spacing: 16) {
                HStack {
                    Text("+852")
                        .font(.headline)
                        .foregroundStyle(AppColor.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .background(AppColor.cardBackground)
                        .cornerRadius(10)

                    TextField("手機號碼", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .font(.title3)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .background(AppColor.cardBackground)
                        .cornerRadius(10)
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(AppColor.error)
                }

                Button {
                    sendOTP()
                } label: {
                    Text("發送驗證碼")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(phoneNumber.count >= 8 ? AppColor.primary : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(phoneNumber.count < 8)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var otpVerificationView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColor.secondary)

                Text("輸入驗證碼")
                    .font(.title2.bold())

                Text("已發送至 +852 \(phoneNumber)")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.top: 20)

            VStack(spacing: 16) {
                TextField("驗證碼", text: $otpCode)
                    .keyboardType(.numberPad)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(AppColor.cardBackground)
                    .cornerRadius(12)

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(AppColor.error)
                }

                Button {
                    verifyOTP()
                } label: {
                    Text("驗證並登入")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(otpCode.count >= 6 ? AppColor.primary : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(otpCode.count < 6)

                Button {
                    step = .phoneEntry
                    otpCode = ""
                    errorText = nil
                } label: {
                    Text("返回更改電話號碼")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.primary)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func sendOTP() {
        let fullPhone = "+852\(phoneNumber)"
        isLoading = true
        errorText = nil

        Task {
            do {
                try await auth.signInWithPhone(phone: fullPhone)
                await MainActor.run {
                    isLoading = false
                    step = .otpVerification
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func verifyOTP() {
        let fullPhone = "+852\(phoneNumber)"
        isLoading = true
        errorText = nil

        Task {
            do {
                try await auth.verifyOTP(phone: fullPhone, token: otpCode)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
