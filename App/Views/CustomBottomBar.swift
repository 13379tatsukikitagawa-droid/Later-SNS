import SwiftUI

/// アパーチャー(絞り)モチーフの撮影ボタン。BeRealのタブバー中央ボタンと同じ考え方で、
/// 選択状態や現在表示中のタブに一切関係なく常にこの見た目で描画する。
/// MainTabViewのネイティブTabViewはタブ項目のアイコンをテンプレート画像として扱い
/// 選択状態に応じて自動的に単色へ塗り替えてしまうため、この色付きボタンは
/// Tab自体の中身(ラベル)には入れず、タブバーの上に独立して重ねる
/// `.overlay(alignment: .bottom)`として使う(タップ判定はallowsHitTesting(false)で
/// 無効化し、下にある「中身が空のcameraタブ」自体のタップに委ねる)。
struct CameraApertureButton: View {
    let isLocked: Bool
    let action: () -> Void

    private static let neonGreen = Color.brandGreen
    private static let ringBackground = Color(hex: "0a0a0a")
    private static let lockedFill = Color.white.opacity(0.05)
    private static let lockedBorder = Color.white.opacity(0.15)
    private static let lockedIconColor = Color(hex: "6b6a63")

    private static let buttonSize: CGFloat = 50
    private static let ringWidth: CGFloat = 3

    var body: some View {
        Button(action: action) {
            ZStack {
                // 周囲の縁取り(4px, #0a0a0a)。laterは背景が暗いため、BeRealの
                // 「同系色の背景に白い円が浮くだけ」とは違い、縁取りで円の輪郭を
                // 明確にする必要がある。
                Circle()
                    .fill(Self.ringBackground)
                    .frame(width: Self.buttonSize + Self.ringWidth * 2, height: Self.buttonSize + Self.ringWidth * 2)

                Group {
                    if isLocked {
                        Circle()
                            .fill(Self.lockedFill)
                            .overlay(
                                Circle().strokeBorder(Self.lockedBorder, lineWidth: 1.5)
                            )
                    } else {
                        Circle()
                            .fill(Self.neonGreen)
                            .shadow(color: Self.neonGreen.opacity(0.35), radius: 14, x: 0, y: 4)
                    }
                }
                .frame(width: Self.buttonSize, height: Self.buttonSize)

                Image(systemName: isLocked ? "lock.fill" : "camera.aperture")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isLocked ? Self.lockedIconColor : Color(hex: "0a0a0a"))
            }
            .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isLocked ? "本日の撮影は終了しました" : "撮影する")
    }
}
