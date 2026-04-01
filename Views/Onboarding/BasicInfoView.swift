import SwiftUI

struct BasicInfoView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository

    private let regionOptions = ["HK", "深圳", "廣州", "澳門", "珠海", "東莞", "海外港人", "其他"]
    private let commitmentOptions = [
        ("全職", "全情投入創業", "flame.fill"),
        ("兼職", "兼顧現有工作", "clock.fill"),
        ("只看看", "先了解一下", "eye.fill")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColor.primary)

                    Text("基本資料")
                        .font(.title.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    Text("呢啲資訊會顯示喺你嘅個人檔案")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.top, 24)

                // Avatar placeholder
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppColor.primary.opacity(0.1))
                            .frame(width: 88, height: 88)

                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundStyle(AppColor.primary)
                    }
                    .padding(.bottom, 4)

                    Text("點擊上傳頭像")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                // Display name
                VStack(alignment: .leading, spacing: 8) {
                    Text("顯示名稱")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(width: 24)

                        TextField("你嘅稱呼", text: $viewModel.displayName)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(14)
                    .background(AppColor.cardBackground)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 24)

                // Region
                VStack(alignment: .leading, spacing: 8) {
                    Text("地區")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    Menu {
                        ForEach(regionOptions, id: \.self) { region in
                            Button(region) {
                                viewModel.region = region
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(AppColor.textSecondary)
                                .frame(width: 24)

                            Text(viewModel.region.isEmpty ? "選擇地區" : viewModel.region)
                                .foregroundStyle(viewModel.region.isEmpty ? AppColor.textSecondary : AppColor.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .padding(14)
                        .background(AppColor.cardBackground)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 24)

                // Languages
                VStack(alignment: .leading, spacing: 8) {
                    Text("語言")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    FlowLayout(spacing: 8) {
                        ForEach(OnboardingViewModel.languageOptions, id: \.self) { lang in
                            let isSelected = viewModel.selectedLanguages.contains(lang)
                            Button {
                                if isSelected {
                                    viewModel.selectedLanguages.remove(lang)
                                } else {
                                    viewModel.selectedLanguages.insert(lang)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: langIcon(lang))
                                        .font(.caption)
                                    Text(lang)
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? AppColor.primary : AppColor.cardBackground)
                                .foregroundStyle(isSelected ? .white : AppColor.textPrimary)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isSelected ? AppColor.primary : AppColor.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Commitment level
                VStack(alignment: .leading, spacing: 8) {
                    Text("投入程度")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.textPrimary)

                    VStack(spacing: 8) {
                        ForEach(commitmentOptions, id: \.0) { option in
                            let isSelected = viewModel.commitmentLevel == option.0
                            Button {
                                viewModel.commitmentLevel = option.0
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: option.2)
                                        .font(.title3)
                                        .foregroundStyle(isSelected ? AppColor.primary : AppColor.textSecondary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.0)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(AppColor.textPrimary)
                                        Text(option.1)
                                            .font(.caption)
                                            .foregroundStyle(AppColor.textSecondary)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppColor.primary)
                                    }
                                }
                                .padding(12)
                                .background(AppColor.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? AppColor.primary : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 24)

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
                .disabled(viewModel.displayName.isEmpty || viewModel.selectedLanguages.isEmpty)
                .opacity(viewModel.displayName.isEmpty || viewModel.selectedLanguages.isEmpty ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
    }

    private func langIcon(_ lang: String) -> String {
        switch lang {
        case "廣東話": return "character.bubble.fill"
        case "普通話": return "character.bubble"
        case "英文": return "a.circle.fill"
        default: return "globe"
        }
    }
}

// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

struct BasicInfoView_Previews: PreviewProvider {
    static var previews: some View {
        BasicInfoView(viewModel: OnboardingViewModel())
            .environmentObject(AuthRepository())
    }
}
