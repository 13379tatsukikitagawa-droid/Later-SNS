import SwiftUI

/// Today's Laterで選ぶ際、理由タグを1つ選ばせる画面。評価対象を「人」ではなく
/// 「瞬間」にするための設計上の配慮(TodaysLaterReasonTag参照)。
struct TodaysLaterReasonPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (TodaysLaterReasonTag) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("この瞬間の、どこが良かったですか?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                ForEach(TodaysLaterReasonTag.allCases) { tag in
                    Button {
                        onSelect(tag)
                        dismiss()
                    } label: {
                        Text(tag.rawValue)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .background(Color.brandBlack.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
