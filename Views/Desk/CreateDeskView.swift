import SwiftUI

struct CreateDeskView: View {
    @EnvironmentObject private var auth: AuthRepository
    @EnvironmentObject private var toast: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 0
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

    private let stepTitles = ["基本", "詳情", "標籤", "預覽"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                wizardStepHeader
                Form {
                    switch step {
                    case 0: basicStepSections
                    case 1: detailsStepSections
                    case 2: tagsStepSections
                    default: previewStepSections
                    }
                    if let errorText {
                        Section {
                            Text(errorText)
                                .foregroundStyle(AppColor.error)
                                .font(.footnote)
                        }
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
                    HStack(spacing: 16) {
                        if step > 0 {
                            Button("上一步") {
                                HapticFeedback.selection()
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                    step = max(0, step - 1)
                                }
                                persistDraft()
                            }
                            .foregroundStyle(AppColor.primary)
                        }
                        if step < 3 {
                            Button("下一步") {
                                HapticFeedback.selection()
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                    step = min(3, step + 1)
                                }
                                persistDraft()
                            }
                            .disabled(!canProceedFromCurrentStep)
                            .fontWeight(.semibold)
                        } else {
                            Button("發佈") {
                                HapticFeedback.medium()
                                Task { await submit() }
                            }
                            .disabled(!isValid || isSubmitting)
                            .fontWeight(.semibold)
                        }
                    }
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
                                    .tint(AppColor.primary)
                                Text("發佈中...")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
            .onAppear {
                loadDraftIfNeeded()
            }
            .onChange(of: name) { _, _ in persistDraft() }
            .onChange(of: pitch) { _, _ in persistDraft() }
            .onChange(of: region) { _, _ in persistDraft() }
            .onChange(of: description) { _, _ in persistDraft() }
            .onChange(of: fundingNeeds) { _, _ in persistDraft() }
            .onChange(of: expectations) { _, _ in persistDraft() }
            .onChange(of: step) { _, _ in persistDraft() }
        }
    }

    private var wizardStepHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? AppColor.primary : AppColor.secondaryGroupedSurface)
                        .frame(height: 4)
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)
                }
            }
            Text("步驟 \(step + 1) / 4：\(stepTitles[step])")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
            Text("草稿會自動儲存在此裝置")
                .font(.caption2)
                .foregroundStyle(AppColor.textTertiary)
        }
        .padding(.horizontal, CardChrome.padding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.background)
    }

    @ViewBuilder
    private var basicStepSections: some View {
        Section {
            VStack(alignment: .trailing, spacing: 4) {
                TextField("Desk 名稱（最多 60 字）", text: $name)
                    .deskerTextFieldNoAutocaps()
                Text("\(name.count)/60")
                    .font(.caption2)
                    .foregroundStyle(name.count > 60 ? AppColor.error : AppColor.textSecondary)
            }
            VStack(alignment: .trailing, spacing: 4) {
                TextField("一句話 Pitch（最多 150 字）", text: $pitch)
                    .deskerTextFieldNoAutocaps()
                Text("\(pitch.count)/150")
                    .font(.caption2)
                    .foregroundStyle(pitch.count > 150 ? AppColor.error : AppColor.textSecondary)
            }
        } header: {
            Text("步驟 1：基本資訊")
        }
    }

    @ViewBuilder
    private var detailsStepSections: some View {
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
            Text("步驟 2：專案詳情（成員可見）")
        }
    }

    @ViewBuilder
    private var tagsStepSections: some View {
        Section {
            ForEach(Self.industryOptions, id: \.self) { industry in
                Button {
                    if selectedIndustries.contains(industry) {
                        selectedIndustries.remove(industry)
                    } else if selectedIndustries.count < 3 {
                        selectedIndustries.insert(industry)
                    }
                    persistDraft()
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
            Text("行業標籤（最多 3 個）")
        }

        Section {
            Picker("地區偏好", selection: $region) {
                ForEach(Self.regionOptions, id: \.self) { r in
                    Text(r).tag(r)
                }
            }
        } header: {
            Text("步驟 3：標籤與偏好")
        }
    }

    @ViewBuilder
    private var previewStepSections: some View {
        Section {
            LabeledContent("名稱", value: name.isEmpty ? "—" : name)
            LabeledContent("Pitch", value: pitch.isEmpty ? "—" : pitch)
            LabeledContent("行業", value: selectedIndustries.isEmpty ? "—" : selectedIndustries.sorted().joined(separator: "、"))
            LabeledContent("地區", value: region)
        } header: {
            Text("預覽")
        }
        Section {
            Text(description.isEmpty ? "（未填寫詳情）" : description)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .lineSpacing(4)
        } header: {
            Text("關於")
        }
        if !fundingNeeds.isEmpty || !expectations.isEmpty {
            Section {
                if !fundingNeeds.isEmpty { LabeledContent("融資", value: fundingNeeds) }
                if !expectations.isEmpty { LabeledContent("期望", value: expectations) }
            }
        }
        Section {
            Text("確認無誤後點「發佈」— 你仍可於稍後編輯 Desk（視功能開放）。")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var canProceedFromCurrentStep: Bool {
        switch step {
        case 0:
            return ProfileFieldValidation.isValidDeskName(name) &&
                !pitch.trimmingCharacters(in: .whitespaces).isEmpty &&
                pitch.count <= 150
        case 1:
            return recruitingRoles.contains { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        case 2:
            return !selectedIndustries.isEmpty
        default:
            return true
        }
    }

    private var isValid: Bool {
        ProfileFieldValidation.isValidDeskName(name) &&
            !pitch.trimmingCharacters(in: .whitespaces).isEmpty &&
            pitch.count <= 150 &&
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

    private func persistDraft() {
        let roles = recruitingRoles.map {
            DeskDraftRole(id: $0.id.uuidString, title: $0.title, count: $0.count, skillsDescription: $0.skillsDescription)
        }
        let draft = DeskCreationDraft(
            step: step,
            name: name,
            pitch: pitch,
            industries: Array(selectedIndustries),
            region: region,
            roles: roles,
            description: description,
            fundingNeeds: fundingNeeds,
            expectations: expectations
        )
        if let data = try? JSONEncoder().encode(draft),
           let s = String(data: data, encoding: .utf8) {
            DeskerUXPreferences.saveDeskDraft(s)
        }
    }

    private func loadDraftIfNeeded() {
        guard let s = DeskerUXPreferences.loadDeskDraft(),
              let data = s.data(using: .utf8),
              let draft = try? JSONDecoder().decode(DeskCreationDraft.self, from: data) else { return }
        step = min(3, max(0, draft.step))
        name = draft.name
        pitch = draft.pitch
        selectedIndustries = Set(draft.industries)
        region = draft.region
        description = draft.description
        fundingNeeds = draft.fundingNeeds
        expectations = draft.expectations
        if !draft.roles.isEmpty {
            recruitingRoles = draft.roles.compactMap { r in
                guard let id = UUID(uuidString: r.id) else { return nil }
                return RecruitingRoleEntry(id: id, title: r.title, count: r.count, skillsDescription: r.skillsDescription)
            }
            if recruitingRoles.isEmpty {
                recruitingRoles = [RecruitingRoleEntry(title: "", count: 1, skillsDescription: "")]
            }
        }
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

            DeskerUXPreferences.saveDeskDraft(nil)
            toast.show(.success, "Desk 已建立")
            HapticFeedback.success()
            isSubmitting = false
            dismiss()
        } catch {
            errorText = error.localizedDescription
            isSubmitting = false
        }
    }
}

private struct RecruitingRoleEntry: Identifiable {
    let id: UUID
    var title: String
    var count: Int
    var skillsDescription: String

    init(id: UUID = UUID(), title: String, count: Int, skillsDescription: String) {
        self.id = id
        self.title = title
        self.count = count
        self.skillsDescription = skillsDescription
    }
}

private struct DeskDraftRole: Codable {
    let id: String
    var title: String
    var count: Int
    var skillsDescription: String
}

private struct DeskCreationDraft: Codable {
    var step: Int
    var name: String
    var pitch: String
    var industries: [String]
    var region: String
    var roles: [DeskDraftRole]
    var description: String
    var fundingNeeds: String
    var expectations: String
}
