import SwiftUI

/// 通報シート。Circle・World Later双方のコンテンツで共用する
/// (ModerationService.ReportTargetType参照)。
struct ReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let targetType: ModerationService.ReportTargetType
    let targetID: String

    @State private var selectedReason: ModerationService.ReportReason = .inappropriate
    @State private var detail: String = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("理由") {
                    Picker("理由", selection: $selectedReason) {
                        ForEach(ModerationService.ReportReason.allCases) { reason in
                            Text(reason.rawValue).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("詳細(任意)") {
                    TextField("状況を教えてください", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("通報する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("送信")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("送信しました", isPresented: $didSubmit) {
                Button("OK") { dismiss() }
            } message: {
                Text("ご報告ありがとうございます。運営が確認します。")
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await ModerationService.submitReport(
                targetType: targetType,
                targetID: targetID,
                reason: selectedReason,
                detail: detail,
                reporterCloudKitUserRecordName: CloudKitManager.current?.currentUserRecordName
            )
            didSubmit = true
        } catch {
            print("[Moderation] submitReport failed: \(error)")
        }
    }
}
