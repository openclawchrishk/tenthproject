import SwiftUI

struct ReportSheetView: View {
    let targetType: ReportTargetType
    let targetId: UUID
    let onSubmit: (ReportDraft) async -> Void

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
                        Text(errorText).foregroundStyle(.red).font(.footnote)
                    }
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSending {
                            HStack { Spacer(); ProgressView(); Spacer() }
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
                    Button("關閉") { dismiss() }
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
        await onSubmit(draft)
        HapticFeedback.success()
        dismiss()
    }
}
