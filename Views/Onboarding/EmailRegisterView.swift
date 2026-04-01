import SwiftUI

struct EmailRegisterView: View {
    @EnvironmentObject private var auth: AuthRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: AuthViewModel
    @State private var showPassword = false
    @State private var showConfirm = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
        case confirm
        case displayName
    }

    init(auth: AuthRepository) {
        _vm = StateObject(wrappedValue: AuthViewModel(auth: auth))
    }

    var body: some View {
        ZStack {
            AppColor.welcomeGradient
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.clear, Color.black.opacity(0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("建立帳戶")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 18) {
                        if vm.needsEmailConfirmation {
                            emailConfirmationBlock
                        } else {
                            registerEmailField
                            registerDisplayNameField
                            registerPasswordField
                            passwordStrengthRow(vm.password)
                            registerConfirmPasswordField

                            if let err = vm.errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(AppColor.error)
                            }

                            Button {
                                Task { await vm.signUpWithEmail() }
                            } label: {
                                Text("註冊")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(AppColor.brandGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(vm.isLoading)
                            .deskerButtonShadow()

                            Button {
                                dismiss()
                            } label: {
                                HStack {
                                    Text("已有帳戶？")
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text("立即登入")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppColor.primary)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppColor.cardBackground)
                            .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        .navigationTitle("建立帳戶")
        .deskerInlineNavigationTitle()
        .onChange(of: auth.session?.user.id) { _, new in
            if new != nil { dismiss() }
        }
        .overlay {
            if vm.isLoading {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            }
        }
        .alert("此電郵已註冊，請直接登入", isPresented: $vm.showEmailAlreadyRegisteredPrompt) {
            Button("登入") { dismiss() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("請使用登入頁面進入帳戶。")
        }
    }

    private var emailConfirmationBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("驗證電郵", systemImage: "envelope.badge.fill")
                .font(.headline)
                .foregroundStyle(AppColor.success)
            Text("我哋已發送驗證連結到你嘅電郵，請檢查收件箱並點擊連結完成註冊。")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            Button("返回登入") { dismiss() }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColor.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var registerEmailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("電郵")
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 22)
                TextField("name@example.com", text: $vm.email)
                    .focused($focusedField, equals: .email)
                    .modifier(RegisterEmailTextFieldPlatform())
                    .deskerTextFieldNoAutocaps()
                    .autocorrectionDisabled()
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .email))
        }
    }

    private var registerDisplayNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("顯示名稱")
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 22)
                TextField("你嘅名稱", text: $vm.displayName)
                    .focused($focusedField, equals: .displayName)
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .displayName))
        }
    }

    private var registerPasswordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("密碼")
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 22)
                Group {
                    if showPassword {
                        TextField("密碼", text: $vm.password)
                    } else {
                        SecureField("密碼", text: $vm.password)
                    }
                }
                .focused($focusedField, equals: .password)
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .password))
        }
    }

    private var registerConfirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("確認密碼")
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 22)
                Group {
                    if showConfirm {
                        TextField("確認密碼", text: $vm.confirmPassword)
                    } else {
                        SecureField("確認密碼", text: $vm.confirmPassword)
                    }
                }
                .focused($focusedField, equals: .confirm)
                Button {
                    showConfirm.toggle()
                } label: {
                    Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .confirm))
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary)
    }

    private func passwordStrengthRow(_ password: String) -> some View {
        let s = PasswordStrengthTier.evaluate(password)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("強度：\(s.label)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(s.tint)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.textTertiary.opacity(0.2))
                        .frame(height: 6)
                    Capsule()
                        .fill(s.barGradient)
                        .frame(width: geo.size.width * s.fillFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private enum PasswordStrengthTier {
        case weak
        case medium
        case strong

        var label: String {
            switch self {
            case .weak: return "弱"
            case .medium: return "中"
            case .strong: return "強"
            }
        }

        var tint: Color {
            switch self {
            case .weak: return AppColor.error
            case .medium: return AppColor.warning
            case .strong: return AppColor.success
            }
        }

        var barGradient: LinearGradient {
            switch self {
            case .weak:
                return LinearGradient(colors: [AppColor.error.opacity(0.85), AppColor.error], startPoint: .leading, endPoint: .trailing)
            case .medium:
                return LinearGradient(colors: [AppColor.warning.opacity(0.85), AppColor.warning], startPoint: .leading, endPoint: .trailing)
            case .strong:
                return LinearGradient(colors: [AppColor.success.opacity(0.85), AppColor.success], startPoint: .leading, endPoint: .trailing)
            }
        }

        var fillFraction: CGFloat {
            switch self {
            case .weak: return 0.33
            case .medium: return 0.66
            case .strong: return 1
            }
        }

        static func evaluate(_ password: String) -> PasswordStrengthTier {
            if password.count < 8 { return .weak }
            let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
            let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
            let hasSymbol = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
            var score = 0
            if password.count >= 12 { score += 1 }
            if hasLetter { score += 1 }
            if hasDigit { score += 1 }
            if hasSymbol { score += 1 }
            if score >= 3 { return .strong }
            if score >= 1 { return .medium }
            return .weak
        }
    }
}

private struct RegisterFieldChrome: ViewModifier {
    let focused: Bool

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        focused ? AppColor.primary : AppColor.textTertiary.opacity(0.35),
                        lineWidth: focused ? 2 : 1
                    )
            )
    }
}

#if os(iOS)
private struct RegisterEmailTextFieldPlatform: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textContentType(.username)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
    }
}
#else
private struct RegisterEmailTextFieldPlatform: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#endif
