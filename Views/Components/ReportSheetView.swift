import SwiftUI

struct ReportSheetView: View {
    let targetType: ReportTargetType
    let targetId: UUID
    let onSubmit: (ReportDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var isSending = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("檢舉原因") {
                    TextField("請描述問題（必填）", text: $reason, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(AppColor.error).font(.footnote)
                    }
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSending {
                            HStack { Spacer(); ProgressView().tint(AppColor.primary); Spacer() }
                        } else {
                            Text("送出檢舉").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSending || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("檢舉")
            .deskerInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        let r = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return }
        isSending = true
        errorText = nil
        defer { isSending = false }
        let draft = ReportDraft(targetType: targetType, targetId: targetId, reason: r)
        do {
            try await onSubmit(draft)
            HapticFeedback.success()
            dismiss()
        } catch {
            HapticFeedback.error()
            errorText = "提交失敗，請稍後再試"
        }
    }
}
