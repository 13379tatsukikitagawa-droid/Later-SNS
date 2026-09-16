import SwiftUI

/// 2026/9 MVP再設計: 下部ナビゲーションの共有バー(ピル型コンテナ)を完全に廃止し、
/// Home・シャッターともそれぞれ独立した丸ボタンとして配置する。「タブが2つしか
/// ないのに5タブ分ありそうな横長のピルが浮いている」という違和感を、入れ物
/// (バー)自体を無くすことで解消する。両ボタンの間に共有の背景・枠は一切置かない。
/// MainTabViewが全画面共通の`.overlay`としてこの1つのコンポーネントだけを使うことで、
/// 個別画面ごとに実装がバラつかないようにする。
struct HomeAndShutterOverlay: View {
    let isShutterLocked: Bool
    let onHome: () -> Void
    let onShutter: () -> Void

    var body: some View {
        ZStack {
            HomeNavButton(action: onHome)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 24)
                .padding(.bottom, 36)

            CameraApertureButton(isLocked: isShutterLocked, action: onShutter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 30)
        }
    }
}

/// Home(二次的な導線)。シャッターより明確に小さく、控えめな色調にする
/// (主役はシャッター側)。タップすると、Home内部で奥へ進んでいたナビゲーション
/// (グループ詳細等)を一気にルートまで戻す(HomeNavigationStore経由)。
struct HomeNavButton: View {
    let action: () -> Void

    private static let diameter: CGFloat = 52
    private static let iconColor = Color(hex: "8fae9a")

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "241a12"), Color(hex: "1c1712")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(Color.brandGreen.opacity(0.25), lineWidth: 1)
                    )
                    .overlay(
                        // ごく薄い上部ハイライト(inset shadowの簡易近似)。
                        Circle()
                            .trim(from: 0.56, to: 0.94)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
                            .rotationEffect(.degrees(90))
                    )

                Image(systemName: "house")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Self.iconColor)
            }
            .frame(width: Self.diameter, height: Self.diameter)
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("ホームに戻る")
    }
}

/// アパーチャー(絞り)モチーフの撮影ボタン。シャッター(主要導線・画面の視覚的な
/// アンカー)としてHomeより明確に大きく、既存の「レンズ/ガラス」の質感ルール
/// (多層グロー・radial gradient・inset風の陰影・左上ハイライト・2層ドロップシャドウ)
/// を適用する。選択状態や現在表示中のタブに一切関係なく常にこの見た目で描画する。
struct CameraApertureButton: View {
    let isLocked: Bool
    let action: () -> Void

    private static let diameter: CGFloat = 68
    private static let lockedFill = Color.white.opacity(0.05)
    private static let lockedBorder = Color.white.opacity(0.15)
    private static let lockedIconColor = Color(hex: "6b6a63")
    private static let iconColor = Color(hex: "123018")
    private static let lightSource = UnitPoint(x: 0.32, y: 0.26)

    var body: some View {
        Button(action: action) {
            ZStack {
                if !isLocked {
                    // 外周グロー(2層)。
                    Circle()
                        .fill(Color.brandGreen.opacity(0.4))
                        .frame(width: Self.diameter + 20, height: Self.diameter + 20)
                        .blur(radius: 6)
                    Circle()
                        .fill(Color.brandGreen.opacity(0.32))
                        .frame(width: Self.diameter + 36, height: Self.diameter + 36)
                        .blur(radius: 16)
                }

                Circle()
                    .fill(
                        isLocked
                            ? AnyShapeStyle(Self.lockedFill)
                            : AnyShapeStyle(
                                RadialGradient(
                                    colors: [Color(hex: "8cf5a8"), Color(hex: "4ade6c"), Color(hex: "2a9950")],
                                    center: Self.lightSource,
                                    startRadius: 0,
                                    endRadius: Self.diameter * 0.75
                                )
                            )
                    )
                    .frame(width: Self.diameter, height: Self.diameter)
                    .overlay(
                        Circle().strokeBorder(Self.lockedBorder, lineWidth: isLocked ? 1.5 : 0)
                    )
                    .overlay(
                        // 下方向のinset shadow(簡易近似): 縁の下半分だけを暗くぼかす。
                        Circle()
                            .trim(from: 0.05, to: 0.45)
                            .stroke(Color.black.opacity(isLocked ? 0 : 0.22), lineWidth: 4)
                            .blur(radius: 3)
                            .rotationEffect(.degrees(90))
                    )

                if !isLocked {
                    // 左上の光の反射ハイライト。
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.55), .clear],
                                center: Self.lightSource,
                                startRadius: 0,
                                endRadius: Self.diameter * 0.4
                            )
                        )
                        .frame(width: Self.diameter, height: Self.diameter)
                }

                Image(systemName: isLocked ? "lock.fill" : "camera.aperture")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isLocked ? Self.lockedIconColor : Self.iconColor)
            }
            .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
            .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(isLocked ? "本日の撮影は終了しました" : "撮影する")
    }
}
