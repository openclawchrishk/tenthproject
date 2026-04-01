import SwiftUI

struct EmailLoginView: View {
    @EnvironmentObject private var auth: AuthRepository
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: AuthViewModel
    @State private var path = NavigationPath()
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    init(auth: AuthRepository) {
        _vm = StateObject(wrappedValue: AuthViewModel(auth: auth))
    }

    var body: some View {
        NavigationStack(path: $path) {
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
                        Text("歡迎回來")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 18) {
                            emailField
                            passwordField

                            HStack {
                                Spacer()
                                NavigationLink(value: EmailLoginRoute.forgotPassword) {
                                    Text("忘記密碼？")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppColor.secondary)
                                }
                            }

                            if let err = vm.errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(AppColor.error)
                            }

                            Button {
                                Task { await vm.signInWithEmail() }
                            } label: {
                                Text("登入")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(AppColor.brandGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(vm.isLoading || !canSubmitEmailLogin)
                            .opacity(canSubmitEmailLogin ? 1 : 0.55)
                            .deskerButtonShadow()

                            NavigationLink(value: EmailLoginRoute.register) {
                                HStack {
                                    Text("未有帳戶？")
                                        .foregroundStyle(AppColor.textSecondary)
                                    Text("立即註冊")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppColor.primary)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
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
            .navigationTitle("登入")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: EmailLoginRoute.self) { route in
                switch route {
                case .register:
                    EmailRegisterView(auth: auth)
                case .forgotPassword:
                    ForgotPasswordView(auth: auth)
                }
            }
        }
        .tint(.white)
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
        .alert("此電郵未註冊，請先註冊", isPresented: $vm.showEmailNotRegisteredPrompt) {
            Button("註冊") {
                path.append(EmailLoginRoute.register)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("你可以立即建立新帳戶。")
        }
    }

    private var canSubmitEmailLogin: Bool {
        let e = vm.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return AuthViewModel.isValidEmail(e) && !vm.password.isEmpty
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("電郵")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 22)
                TextField("name@example.com", text: $vm.email)
                    .focused($focusedField, equals: .email)
                    .modifier(EmailTextFieldPlatform())
                    .deskerTextFieldNoAutocaps()
                    .autocorrectionDisabled()
            }
            .modifier(EmailFieldModifiers(focused: focusedField == .email))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("密碼")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
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
            .modifier(EmailFieldModifiers(focused: focusedField == .password))
        }
    }
}

private struct EmailFieldModifiers: ViewModifier {
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

private enum EmailLoginRoute: Hashable {
    case register
    case forgotPassword
}

#if os(iOS)
private struct EmailTextFieldPlatform: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textContentType(.username)
            .keyboardType(.emailAddress)
    }
}
#else
private struct EmailTextFieldPlatform: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#endif
