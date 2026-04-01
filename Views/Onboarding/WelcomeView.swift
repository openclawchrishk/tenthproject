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
                colors: [Color.black.opacity(0.18), Color.clear, Color.black.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            WelcomeLuxuryBackdrop()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                if !SupabaseManager.shared.isConfigured {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Supabase 未配置 - 請聯繫開發者")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusSmall, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }

                Spacer()

                VStack(spacing: 22) {
                    ZStack {
                        ForEach(0..<3, id: \.self) { ring in
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [
                                            AppColor.gold.opacity(0.9),
                                            AppColor.platinum.opacity(0.5),
                                            AppColor.gold.opacity(0.85),
                                        ],
                                        center: .center
                                    ),
                                    lineWidth: ring == 0 ? 2.5 : 1.5
                                )
                                .frame(width: 108 + CGFloat(ring) * 22, height: 108 + CGFloat(ring) * 22)
                                .opacity(1.0 - Double(ring) * 0.12)
                        }

                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 88))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, AppColor.gold.opacity(0.98))
                            .shadow(color: Color.black.opacity(0.35), radius: 24, y: 10)
                            .shadow(color: AppColor.gold.opacity(0.35), radius: 16, y: 0)
                    }

                    Text("Desker HK")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(AppColor.goldAccentGradient)

                    Text("遇見你的下一個Desk")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                }
                .padding(.bottom, 36)

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
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .accessibilityLabel("使用 Apple 登入")
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
                    .disabled(isLoading)

                    Button {
                        showPhoneLogin = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "phone.fill")
                            Text("使用手機號碼登入")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColor.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                .fill(.regularMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        )
                    }
                    .buttonStyle(DeskerButtonPressStyle())
                    .accessibilityLabel("使用手機號碼登入")
                    .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 6)
                    .disabled(isLoading)

                    Button {
                        showingEmailLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("使用 Email")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppColor.gold.opacity(0.55), Color.white.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(DeskerButtonPressStyle())
                    .accessibilityLabel("使用 Email 登入")
                    .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
                    .disabled(isLoading)

                    if let errorText {
                        Text(errorText)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

                legalFooter
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }

            if isLoading {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.45)
                    .tint(AppColor.gold)
            }
        }
        .sheet(isPresented: $showPhoneLogin, onDismiss: {}) {
            PhoneLoginView()
                .environmentObject(auth)
                .deskerSheetSpringContent()
        }
        .sheet(isPresented: $showingEmailLogin, onDismiss: {}) {
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

/// Soft light drift + speckle behind the welcome hero (non-interactive).
private struct WelcomeLuxuryBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let drift = sin(t * 0.35) * 0.5 + 0.5
                ZStack {
                    RadialGradient(
                        colors: [AppColor.secondary.opacity(0.22), Color.clear],
                        center: UnitPoint(x: 0.15 + drift * 0.1, y: 0.2),
                        startRadius: 4,
                        endRadius: geo.size.width * 0.85
                    )
                    RadialGradient(
                        colors: [AppColor.gold.opacity(0.12), Color.clear],
                        center: UnitPoint(x: 0.85 - drift * 0.08, y: 0.35),
                        startRadius: 2,
                        endRadius: geo.size.height * 0.55
                    )
                    Canvas { context, size in
                        let sparkle = CGFloat(sin(t * 1.1) * 0.5 + 0.5)
                        for i in 0..<32 {
                            let px = CGFloat((i * 47) % Int(max(size.width, 1))) / max(size.width, 1)
                            let py = CGFloat((i * 91) % Int(max(size.height * 0.5, 1))) / max(size.height, 1)
                            let x = px * size.width
                            let y = py * size.height * 0.55 + CGFloat(i % 3) * 6
                            let r = 1.2 + sparkle * CGFloat(i % 3) * 0.35
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                with: .color(Color.white.opacity(0.04 + sparkle * 0.03))
                            )
                        }
                    }
                }
            }
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

                ScrollView {
                    VStack(spacing: 32) {
                        if step == .phoneEntry {
                            phoneEntryView
                        } else {
                            otpVerificationView
                        }
                    }
                    .padding()
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif

                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(AppColor.gold)
                }
            }
            .navigationTitle(step == .phoneEntry ? "手機登入" : "驗證碼")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .deskerKeyboardDismissToolbar()
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
                        .onChange(of: phoneNumber) { _, new in
                            let capped = String(new.filter(\.isNumber).prefix(8))
                            if capped != new { phoneNumber = capped }
                        }
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
                            .foregroundStyle(AppColor.primary)
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
                            ProfileFieldValidation.isValidHongKongMobileLocalDigits(phoneNumber)
                            ? AppColor.brandGradient
                            : LinearGradient(colors: [AppColor.textTertiary], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(DeskerButtonPressStyle())
                .disabled(!ProfileFieldValidation.isValidHongKongMobileLocalDigits(phoneNumber) || isLoading)
                .deskerButtonShadow()
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
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
                            .foregroundStyle(AppColor.primary)
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
                .disabled(otpCode.count < 6 || isLoading)
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
            .padding(.bottom, 32)
        }
    }

    private func sendOTP() {
        let digits = phoneNumber.filter(\.isNumber)
        guard ProfileFieldValidation.isValidHongKongMobileLocalDigits(digits) else {
            errorText = "請輸入有效嘅香港手機號碼（8 位數字）"
            return
        }
        let fullPhone = "+852\(digits)"
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
        let digits = phoneNumber.filter(\.isNumber)
        let fullPhone = "+852\(digits)"
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
