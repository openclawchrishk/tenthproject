import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(AppColor.brandGradient)

                    Text("選擇你嘅角色")
                        .font(.title.bold())
                        .tracking(-0.4)
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

struct RoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColor.brandGradient)
                        .frame(width: 56, height: 56)
                        .shadow(color: AppColor.gold.opacity(0.22), radius: 10, x: 0, y: 4)

                    Image(systemName: roleIcon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(role.localizedName)
                        .font(.headline.weight(.semibold))
                        .tracking(-0.2)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    if !isSelected {
                        Circle()
                            .stroke(AppColor.textTertiary.opacity(0.45), lineWidth: 2)
                            .frame(width: 28, height: 28)
                    }
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(AppColor.gold)
                            .shadow(color: AppColor.gold.opacity(0.45), radius: 6, y: 0)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 32, height: 32)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .fill(AppColor.cardBackground)
                    .shadow(
                        color: Color.black.opacity(CardChrome.shadowOpacityCard),
                        radius: CardChrome.shadowRadiusCard,
                        x: 0,
                        y: CardChrome.shadowYCard
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous)
                    .stroke(isSelected ? AppColor.gold : Color.clear, lineWidth: 2.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: CardChrome.cornerRadiusLarge, style: .continuous))
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.36, dampingFraction: 0.68), value: isSelected)
        }
        .buttonStyle(DeskerCardPressStyle())
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
        case .founder: return "已經或正在建立團隊與產品，想搵人、搵資源。"
        case .aspiringFounder: return "準備起步，想識合夥人、導師或好項目。"
        case .investor: return "關注早期項目，願意投入資金與網絡。"
        case .mentor: return "喺行業打滾過，樂意分享經驗同引路。"
        }
    }
}

struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView(viewModel: OnboardingViewModel())
    }
}
