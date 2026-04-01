import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 48))
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

                // Role cards
                VStack(spacing: 16) {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        RoleCard(
                            role: role,
                            isSelected: viewModel.selectedRole == role,
                            onSelect: { viewModel.selectedRole = role }
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 32)

                // Continue button
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
                    .background(
                        LinearGradient(
                            colors: [AppColor.primary, AppColor.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .disabled(viewModel.selectedRole == nil)
                .opacity(viewModel.selectedRole == nil ? 0.5 : 1)
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
                // Icon
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: roleIcon)
                        .font(.title2)
                        .foregroundStyle(roleColor)
                }

                // Text
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

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? roleColor : AppColor.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if isSelected {
                        Circle()
                            .fill(roleColor)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColor.cardBackground)
                    .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05), radius: isSelected ? 10 : 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? roleColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var roleIcon: String {
        switch role {
        case .founder: return "lightbulb.fill"
        case .aspiringFounder: return "sparkles"
        case .investor: return "dollarsign.circle.fill"
        case .mentor: return "graduationcap.fill"
        }
    }

    private var roleColor: Color {
        switch role {
        case .founder: return AppColor.primary
        case .aspiringFounder: return AppColor.secondary
        case .investor: return AppColor.success
        case .mentor: return AppColor.accentOrange
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
