import SwiftUI
import AuthenticationServices
import CryptoKit

struct WelcomeView: View {
    @EnvironmentObject private var auth: AuthRepository
    @Environment(\.openURL) private var openURL
    @State private var showPhoneLogin = false
    @State private var showingEmailLogin = false
    @State private var isLoading = false
    @State private var errorText: String?
    /// Raw nonce for the current Sign in with Apple request; must match `signInWithApple(idToken:nonce:)`.
    @State private var currentAppleNonce = ""

    private static func generateNonce() -> String {
        let letters = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        var nonce = ""
        for _ in 0..<32 {
            nonce += String(letters.randomElement() ?? "0")
        }
        return nonce
    }

    private static func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    var body: some View {
        ZStack {
            AppColor.welcomeGradient
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.clear, Color.black.opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 88))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, AppColor.gold.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.15), radius: 18, y: 8)

                    Text("Desker HK")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppColor.gold)

                    Text("遇見你的下一個Desk")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)

                Spacer()

                VStack(spacing: 14) {
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            let raw = Self.generateNonce()
                            currentAppleNonce = raw
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = Self.sha256Hex(raw)
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("使用 Apple 登入")
                    .deskerButtonShadow()

                    Button {
                        showPhoneLogin = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "phone.fill")
                            Text("使用手機號碼登入")
                        }
                        .font(.headline)
                        .foregroundStyle(AppColor.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                        )
                    }
                    .buttonStyle(DeskerButtonPressStyle())
                    .accessibilityLabel("使用手機號碼登入")
                    .deskerButtonShadow()

                    Button {
                        showingEmailLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("使用 Email")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.cardBackground.opacity(0.22))
                        .cornerRadius(12)
                    }
                    .buttonStyle(DeskerButtonPressStyle())
                    .accessibilityLabel("使用 Email 登入")
                    .deskerButtonShadow()

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

                legalFooter
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
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
                .deskerSheetSpringContent()
        }
        .sheet(isPresented: $showingEmailLogin) {
            EmailLoginView(auth: auth)
                .environmentObject(auth)
                .deskerSheetSpringContent()
        }
    }

    private var legalFooter: some View {
        ViewThatFits(in: .vertical) {
            legalLine
            legalStacked
        }
    }

    private var legalLine: some View {
        HStack(spacing: 0) {
            Text("登入即表示你同意我們的 ")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
            Button("服務條款") {
                openURL(PublicLinks.termsURL)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            Text(" 和 ")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
            Button("私隱政策") {
                openURL(PublicLinks.privacyURL)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
        }
        .multilineTextAlignment(.center)
    }

    private var legalStacked: some View {
        VStack(spacing: 6) {
            Text("登入即表示你同意我們的")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 8) {
                Button("服務條款") {
                    openURL(PublicLinks.termsURL)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                Text("和")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                Button("私隱政策") {
                    openURL(PublicLinks.privacyURL)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
            }
        }
        .multilineTextAlignment(.center)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
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
                    try await auth.signInWithApple(idToken: idTokenString, nonce: currentAppleNonce)
                    await MainActor.run { isLoading = false }
                } catch {
                    await MainActor.run {
                        errorText = "登入失敗：\(APIErrorMessages.userFacingMessage(for: error))"
                        isLoading = false
                    }
                }
            }

        case .failure(let error):
            errorText = "Apple 登入失敗：\(APIErrorMessages.userFacingMessage(for: error))"
        }
    }
}

#if os(iOS)
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
                        .tint(AppColor.primary)
                }
            }
            .navigationTitle(step == .phoneEntry ? "手機登入" : "驗證碼")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .tint(AppColor.primary)
        }
    }

    private var phoneEntryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColor.primary)

                Text("輸入你嘅手機號碼")
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textPrimary)

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
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                        .shadow(color: CardChrome.buttonShadowColor, radius: CardChrome.shadowRadiusButton, x: 0, y: CardChrome.shadowYButton)

                    TextField("手機號碼", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .font(.title3)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 12)
                        .background(AppColor.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusChip, style: .continuous)
                                .stroke(AppColor.textTertiary.opacity(0.35), lineWidth: 1)
                        )
                }

                if let errorText {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColor.error)
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(AppColor.error)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    sendOTP()
                } label: {
                    Text("發送驗證碼")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            phoneNumber.count >= 8
                            ? AppColor.brandGradient
                            : LinearGradient(colors: [AppColor.textTertiary], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(DeskerButtonPressStyle())
                .disabled(phoneNumber.count < 8)
                .deskerButtonShadow()
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var otpVerificationView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColor.primary)

                Text("輸入驗證碼")
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textPrimary)

                Text("已發送至 +852 \(phoneNumber)")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.top, 20)

            VStack(spacing: 16) {
                TextField("驗證碼", text: $otpCode)
                    .keyboardType(.numberPad)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(AppColor.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                            .stroke(AppColor.primary.opacity(0.35), lineWidth: 2)
                    )

                if let errorText {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColor.error)
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(AppColor.error)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    verifyOTP()
                } label: {
                    Text("驗證並登入")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            otpCode.count >= 6
                            ? AppColor.brandGradient
                            : LinearGradient(colors: [AppColor.textTertiary], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(DeskerButtonPressStyle())
                .disabled(otpCode.count < 6)
                .deskerButtonShadow()

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
                    errorText = APIErrorMessages.userFacingMessage(for: error)
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
                    errorText = APIErrorMessages.userFacingMessage(for: error)
                    isLoading = false
                }
            }
        }
    }
}
#else
struct PhoneLoginView: View {
    @EnvironmentObject private var auth: AuthRepository

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "手機登入",
                systemImage: "phone.fill",
                description: Text("此平台不支援手機登入。")
            )
        }
    }
}
#endif
