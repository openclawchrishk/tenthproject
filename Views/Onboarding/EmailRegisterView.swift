import SwiftUI

struct EmailRegisterView: View {
    @EnvironmentObject private var auth: AuthRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: AuthViewModel
    @State private var showPassword = false
    @State private var showConfirm = false
    @State private var formShakeTick = 0
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
                                    .fixedSize(horizontal: false, vertical: true)
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
                    .deskerShake(trigger: formShakeTick)
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
        .onChange(of: vm.validationShakeTick) { _, _ in
            formShakeTick += 1
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
                TextField("電郵地址", text: $vm.email)
                    .focused($focusedField, equals: .email)
                    .modifier(RegisterEmailTextFieldPlatform())
                    .deskerTextFieldNoAutocaps()
                    .autocorrectionDisabled()
                    .onChange(of: vm.email) { _, _ in vm.fieldErrorEmail = nil }
                if AuthViewModel.isValidEmail(vm.email.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.success)
                        .accessibilityLabel("格式正確")
                }
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .email, invalid: vm.fieldErrorEmail != nil))
            if let err = vm.fieldErrorEmail {
                Text(err).font(.caption).foregroundStyle(AppColor.error)
            }
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
                    .onChange(of: vm.displayName) { _, _ in vm.fieldErrorDisplayName = nil }
                if registerDisplayNameLooksValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColor.success)
                }
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .displayName, invalid: vm.fieldErrorDisplayName != nil))
            if let err = vm.fieldErrorDisplayName {
                Text(err).font(.caption).foregroundStyle(AppColor.error)
            }
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
                .onChange(of: vm.password) { _, _ in vm.fieldErrorPassword = nil }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .password, invalid: vm.fieldErrorPassword != nil))
            if let err = vm.fieldErrorPassword {
                Text(err).font(.caption).foregroundStyle(AppColor.error)
            }
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
                .onChange(of: vm.confirmPassword) { _, _ in vm.fieldErrorConfirmPassword = nil }
                Button {
                    showConfirm.toggle()
                } label: {
                    Image(systemName: showConfirm ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .modifier(RegisterFieldChrome(focused: focusedField == .confirm, invalid: vm.fieldErrorConfirmPassword != nil))
            if let err = vm.fieldErrorConfirmPassword {
                Text(err).font(.caption).foregroundStyle(AppColor.error)
            }
        }
    }

    private var registerDisplayNameLooksValid: Bool {
        let name = vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= ProfileFieldValidation.displayNameMaxLength
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary)
    }

    private func passwordStrengthRow(_ password: String) -> some View {
        let s = ProfileFieldValidation.PasswordStrength.evaluate(password)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("強度：\(s.strengthLabel)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(strengthTint(s))
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.textTertiary.opacity(0.2))
                        .frame(height: 6)
                    Capsule()
                        .fill(strengthBarGradient(s))
                        .frame(width: geo.size.width * strengthFill(s), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func strengthTint(_ s: ProfileFieldValidation.PasswordStrength) -> Color {
        switch s {
        case .weak: return AppColor.error
        case .medium: return AppColor.warning
        case .strong: return AppColor.success
        }
    }

    private func strengthFill(_ s: ProfileFieldValidation.PasswordStrength) -> CGFloat {
        switch s {
        case .weak: return 0.33
        case .medium: return 0.66
        case .strong: return 1
        }
    }

    private func strengthBarGradient(_ s: ProfileFieldValidation.PasswordStrength) -> LinearGradient {
        switch s {
        case .weak:
            return LinearGradient(colors: [AppColor.error.opacity(0.85), AppColor.error], startPoint: .leading, endPoint: .trailing)
        case .medium:
            return LinearGradient(colors: [AppColor.warning.opacity(0.85), AppColor.warning], startPoint: .leading, endPoint: .trailing)
        case .strong:
            return LinearGradient(colors: [AppColor.success.opacity(0.85), AppColor.success], startPoint: .leading, endPoint: .trailing)
        }
    }
}

private struct RegisterFieldChrome: ViewModifier {
    let focused: Bool
    var invalid: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        invalid ? AppColor.error : (focused ? AppColor.primary : AppColor.textTertiary.opacity(0.35)),
                        lineWidth: invalid || focused ? 2 : 1
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
