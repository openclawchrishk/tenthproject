import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppColor.primary)

                    Text("選擇你嘅角色")
                        .font(.title.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    Text("呢個會影響你喺社群嘅身份顯示")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(spacing: 16) {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        RoleCard(
                            role: role,
                            isSelected: viewModel.selectedRole == role,
                            onSelect: {
                                HapticFeedback.light()
                                viewModel.selectedRole = role
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 32)

                Button {
                    viewModel.proceedToNextStep()
                } label: {
                    HStack {
                        Text("繼續")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.brandGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusMedium, style: .continuous))
                }
                .buttonStyle(DeskerButtonPressStyle())
                .disabled(viewModel.selectedRole == nil)
                .opacity(viewModel.selectedRole == nil ? 0.5 : 1)
                .deskerButtonShadow()
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

private struct RoleCardScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct RoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColor.primary.opacity(0.1))
                        .frame(width: 52, height: 52)

                    Image(systemName: roleIcon)
                        .font(.title2)
                        .foregroundStyle(AppColor.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(role.localizedName)
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppColor.gold)
                } else {
                    Circle()
                        .stroke(AppColor.textTertiary.opacity(0.45), lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(color: CardChrome.shadowColor, radius: CardChrome.shadowRadiusElevated, x: 0, y: CardChrome.shadowYElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .stroke(isSelected ? AppColor.gold.opacity(0.85) : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous))
        }
        .buttonStyle(RoleCardScaleStyle())
    }

    private var roleIcon: String {
        switch role {
        case .founder: return "lightbulb.fill"
        case .aspiringFounder: return "sparkles"
        case .investor: return "dollarsign.circle.fill"
        case .mentor: return "graduationcap.fill"
        }
    }
}

extension UserRole {
    var description: String {
        switch self {
        case .founder: return "正在建立或經營創業項目"
        case .aspiringFounder: return "有創業意向，尋找合夥人或項目"
        case .investor: return "天使投資者或 VC 代表"
        case .mentor: return "有行業經驗，提供指導"
        }
    }
}

struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView(viewModel: OnboardingViewModel())
    }
}
