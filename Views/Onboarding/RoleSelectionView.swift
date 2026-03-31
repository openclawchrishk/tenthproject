import SwiftUI

struct RoleSelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("選擇你的主要角色")
                .font(.largeTitle)
                .bold()
                .padding(.top, 40)
            
            Text("這將決定你在 Explore 的預設排序與 Profile 顯示")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                ForEach(UserRole.allCases, id: \.self) { role in
                    RoleCard(
                        role: role,
                        isSelected: viewModel.selectedRole == role,
                        onSelect: { viewModel.selectedRole = role }
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                viewModel.proceedToNextStep()
            }) {
                Text("下一步")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedRole == nil ? Color.gray : AppColor.primary)
                    .cornerRadius(12)
            }
            .disabled(viewModel.selectedRole == nil)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
}

struct RoleCard: View {
    let role: UserRole
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.localizedName)
                        .font(.headline)
                    
                    Text(roleDescription(for: role))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColor.primary)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColor.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func roleDescription(for role: UserRole) -> String {
        switch role {
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
