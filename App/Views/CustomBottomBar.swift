import SwiftUI

/// 撮影ボタン。撮影は「モードの切り替え」ではなく単発のアクションのため、
/// HIG準拠でタブ(TabViewの構造)には含めず、画面のコンテンツレイヤーに浮かぶ
/// 独立したLiquid Glassボタンとして実装する。質感・押下時のインタラクション
/// (ガラスの反射・弾み)はシステムの`.glassEffect(.regular.interactive())`に
/// 委ね、ブランドカラー(緑)はアイコンの着色のみに留める(ガラスの背景自体は
/// 緑で塗りつぶさない)。
struct CameraApertureButton: View {
    let isLocked: Bool
    let action: () -> Void

    private static let accent = Color.laterAccent
    private static let buttonSize: CGFloat = 56

    var body: some View {
        Button(action: action) {
            Image(systemName: isLocked ? "lock.fill" : "camera.aperture")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isLocked ? Color.secondary : Self.accent)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(isLocked ? "本日の撮影は終了しました" : "撮影する")
    }
}
