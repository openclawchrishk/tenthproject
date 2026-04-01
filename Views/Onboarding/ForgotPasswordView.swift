import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: AuthViewModel
    @FocusState private var emailFocused: Bool

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
                    Text("重置密碼")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 18) {
                        if vm.isPasswordResetSent {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppColor.success)
                                    Text("重置連結已發送！請檢查你的郵箱")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppColor.textPrimary)
                                }
                                Button {
                                    dismiss()
                                } label: {
                                    Text("返回登入")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(AppColor.brandGradient)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .deskerButtonShadow()
                            }
                        } else {
                            Text("請輸入你的電郵地址，我哋會發送重置連結")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("電郵")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColor.textPrimary)

                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(AppColor.textSecondary)
                                    .frame(width: 22)
                                TextField("name@example.com", text: $vm.email)
                                    .modifier(ForgotPasswordEmailFieldPlatform())
                                    .autocorrectionDisabled()
                                    .deskerTextFieldNoAutocaps()
                                    .focused($emailFocused)
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        emailFocused ? AppColor.primary : AppColor.textTertiary.opacity(0.35),
                                        lineWidth: emailFocused ? 2 : 1
                                    )
                            )

                            if let err = vm.errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(AppColor.error)
                            }

                            Button {
                                Task { await vm.resetPassword() }
                            } label: {
                                Text("發送重置連結")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(AppColor.brandGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(vm.isLoading)
                            .deskerButtonShadow()
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
        .deskerInlineNavigationTitle()
        .overlay {
            if vm.isLoading {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            }
        }
    }
}

#if os(iOS)
private struct ForgotPasswordEmailFieldPlatform: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textContentType(.username)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
    }
}
#else
private struct ForgotPasswordEmailFieldPlatform: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
#endif
