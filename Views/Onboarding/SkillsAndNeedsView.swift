import SwiftUI
import UIKit

struct SkillsAndNeedsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var auth: AuthRepository
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("產業與技能")
                    .font(.largeTitle.bold())
                    .padding(.top, 24)

                TagSection(
                    title: "產業標籤",
                    subtitle: "選擇你關注或從事的產業",
                    options: OnboardingViewModel.industryOptions,
                    selection: $viewModel.industryTags,
                    accent: AppColor.primary
                )

                TagSection(
                    title: "技能",
                    subtitle: "你擅長的能力",
                    options: OnboardingViewModel.skillOptions,
                    selection: $viewModel.skills,
                    accent: AppColor.secondary
                )

                TagSection(
                    title: "需求",
                    subtitle: "你希望配對到的協助",
                    options: OnboardingViewModel.needOptions,
                    selection: $viewModel.needs,
                    accent: AppColor.accentOrange
                )

                if let saveError {
                    Text(saveError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(action: {
                    Task { await saveAndContinue() }
                }) {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("完成並儲存")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColor.brandGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .disabled(isSaving)
                .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private func saveAndContinue() async {
        guard auth.session != nil else {
            saveError = "尚未登入，無法儲存。請先完成登入，再填寫產業與技能。"
            return
        }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            try await viewModel.persistSkillsAndNeeds(auth: auth)
            viewModel.proceedToNextStep()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct TagSection: View {
    let title: String
    let subtitle: String
    let options: [String]
    @Binding var selection: Set<String>
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let on = selection.contains(option)
                    Button {
                        if on { selection.remove(option) } else { selection.insert(option) }
                    } label: {
                        Text(option)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(on ? accent.opacity(0.2) : Color(UIColor.secondarySystemGroupedBackground))
                            .foregroundStyle(on ? accent : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(on ? accent : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
