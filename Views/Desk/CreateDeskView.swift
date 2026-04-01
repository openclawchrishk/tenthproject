import SwiftUI

struct CreateDeskView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var pitch: String = ""
    @State private var selectedIndustries: Set<String> = []
    @State private var region: String = "HK"
    @State private var recruitingRoles: [RecruitingRoleEntry] = [
        RecruitingRoleEntry(title: "", count: 1, skillsDescription: "")
    ]
    @State private var description: String = ""
    @State private var fundingNeeds: String = ""
    @State private var expectations: String = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    private let deskRepository = DeskRepository()

    static let industryOptions = [
        "金融科技", "教育", "醫療健康", "電商", "SaaS", "AI / 數據", "區塊鏈", "消費品牌", "餐飲", "零售", "物流", "房地產", "媒體", "遊戲"
    ]

    static let regionOptions = [
        "HK", "深圳", "廣州", "澳門", "珠海", "東莞", "其他大灣區", "海外港人", "其他"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Desk 名稱（最多 60 字）", text: $name)
                        .deskerTextFieldNoAutocaps()
                    TextField("一句話 Pitch（最多 150 字）", text: $pitch)
                        .deskerTextFieldNoAutocaps()
                } header: {
                    Text("基本資訊")
                }

                Section {
                    ForEach(Self.industryOptions, id: \.self) { industry in
                        Button {
                            if selectedIndustries.contains(industry) {
                                selectedIndustries.remove(industry)
                            } else if selectedIndustries.count < 3 {
                                selectedIndustries.insert(industry)
                            }
                        } label: {
                            HStack {
                                Text(industry)
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                if selectedIndustries.contains(industry) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColor.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("行業標籤（最多選 3 個）")
                }

                Section {
                    Picker("地區", selection: $region) {
                        ForEach(Self.regionOptions, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                } header: {
                    Text("地區")
                }

                Section {
                    ForEach(Array(recruitingRoles.enumerated()), id: \.element.id) { index, role in
                        recruitingRoleRow(index: index, role: role)
                    }
                    Button {
                        recruitingRoles.append(RecruitingRoleEntry(title: "", count: 1, skillsDescription: ""))
                    } label: {
                        Label("添加招募角色", systemImage: "plus.circle.fill")
                            .foregroundStyle(AppColor.primary)
                    }
                } header: {
                    Text("招募角色")
                }

                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                    TextField("融資需求 / 投資規模", text: $fundingNeeds)
                        .deskerTextFieldNoAutocaps()
                    TextField("對申請者的期望（選填）", text: $expectations)
                        .deskerTextFieldNoAutocaps()
                } header: {
                    Text("詳細資訊（成員可見）")
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(AppColor.error)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("創建 Desk")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("發佈") {
                        HapticFeedback.medium()
                        Task { await submit() }
                    }
                    .disabled(!isValid || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
            .disabled(isSubmitting)
            .deskerSheetSpringContent()
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(AppColor.secondary)
                                Text("發佈中...")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !pitch.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedIndustries.isEmpty &&
        recruitingRoles.contains { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    @ViewBuilder
    private func recruitingRoleRow(index: Int, role: RecruitingRoleEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("角色名稱（如：CTO、市場負責人）", text: Binding(
                    get: { recruitingRoles[index].title },
                    set: { recruitingRoles[index].title = $0 }
                ))
                .deskerTextFieldNoAutocaps()

                Stepper("\(recruitingRoles[index].count)人", value: Binding(
                    get: { recruitingRoles[index].count },
                    set: { recruitingRoles[index].count = max(1, $0) }
                ), in: 1...10)
            }

            TextField("所需技能描述（選填）", text: Binding(
                get: { recruitingRoles[index].skillsDescription },
                set: { recruitingRoles[index].skillsDescription = $0 }
            ))
            .deskerTextFieldNoAutocaps()
            .font(.caption)
            .foregroundStyle(AppColor.textSecondary)

            if recruitingRoles.count > 1 {
                HStack {
                    Spacer()
                    Button(role.title.isEmpty ? "移除" : "移除「\(role.title)」") {
                        recruitingRoles.remove(at: index)
                    }
                    .font(.caption)
                    .foregroundStyle(AppColor.error)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func submit() async {
        guard isValid else { return }
        guard let founderId = auth.currentUser?.id else {
            errorText = "請先登入"
            return
        }

        isSubmitting = true
        errorText = nil

        do {
            let roles = recruitingRoles
                .filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { DeskRole(title: $0.title, count: $0.count, skillDescription: $0.skillsDescription.isEmpty ? nil : $0.skillsDescription) }

            try await deskRepository.createDesk(
                founderId: founderId,
                name: name.trimmingCharacters(in: .whitespaces),
                pitch: pitch.trimmingCharacters(in: .whitespaces),
                industries: Array(selectedIndustries),
                region: region,
                recruitingRoles: roles,
                description: description.isEmpty ? nil : description,
                fundingNeeds: fundingNeeds.isEmpty ? nil : fundingNeeds,
                expectations: expectations.isEmpty ? nil : expectations
            )

            toast.show(.success, "Desk 已建立")
            HapticFeedback.success()
            dismiss()
        } catch {
            errorText = error.localizedDescription
            isSubmitting = false
        }
    }
}

private struct RecruitingRoleEntry: Identifiable {
    let id = UUID()
    var title: String
    var count: Int
    var skillsDescription: String
}
