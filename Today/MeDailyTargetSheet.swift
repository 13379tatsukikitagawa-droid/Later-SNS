import SwiftUI

/// 「ME」の当日の目標撮影枚数(1〜20)をユーザー自身に選んでもらうシート。
/// ここでは選択状態を保持するだけで、LaterGroup.personalDailyTargetCount /
/// personalTargetLastSetDateへの反映は呼び出し元のonConfirmに任せる
/// (GroupHomeDetailView参照。確定して初めてその日の目標として確定する)。
struct MeDailyTargetSheet: View {
    let onConfirm: (Int) -> Void

    @State private var selectedCount: Int
    @Environment(\.dismiss) private var dismiss

    private static let range = Array(1...20)

    init(initialValue: Int, onConfirm: @escaping (Int) -> Void) {
        _selectedCount = State(initialValue: initialValue)
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("今日の目標を設定")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("目標枚数に届くまで、今日撮った写真はロックされたままになります")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 32)
            .padding(.bottom, 12)

            Picker("目標枚数", selection: $selectedCount) {
                ForEach(Self.range, id: \.self) { count in
                    Text("\(count)枚")
                        .foregroundStyle(.white)
                        .tag(count)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 170)
            .colorScheme(.dark)

            Button {
                onConfirm(selectedCount)
                dismiss()
            } label: {
                Text("本日の目標を確定")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 24)
        .background(Color.brandBlack.ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}
