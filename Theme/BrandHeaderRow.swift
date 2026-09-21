import SwiftUI

/// Homeタブ(Personal/Community共通)のブランドヘッダー行。緑・太字の「Later」ロゴ+
/// 発光するアパーチャーアイコン+現像中ボタンで構成する。ロゴ部分をタップすると
/// Laterの紹介サイトを開く(以前あった「Laterについて」テキストリンクの代替)。
/// TodayShootingView(Community)とPersonalTodayViewの両方から使う共通コンポーネント。
struct BrandHeaderRow: View {
    let developingPhotoCount: Int
    let onTapDeveloping: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var developingPulse = false

    private static let neonGreen = Color.brandGreen
    private static let aboutSiteURL = URL(string: "https://13379tatsukikitagawa-droid.github.io/APP-Later2/")!

    var body: some View {
        HStack(spacing: 10) {
            Button {
                openURL(Self.aboutSiteURL)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Self.neonGreen)
                        .shadow(color: Self.neonGreen.opacity(0.6), radius: 8)

                    Text("Later")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Self.neonGreen)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            developingButton
        }
        .padding(.top, 8)
    }

    // MARK: - 現像中ボタン

    private var developingButton: some View {
        Button(action: onTapDeveloping) {
            HStack(spacing: 8) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(developingPhotoCount > 0 ? "現像中 (\(developingPhotoCount)枚)" : "現像中")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Self.neonGreen)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            // ネオングリーンの発光感は0枚の状態でも常に見える(以前はここが従来の
            // グレー表示に戻ってしまい、「今日まだ撮影していない」通常時には見た目が
            // 変わって見えないという不具合になっていた)。現像中の写真がある間は
            // グラデーション・枠線・シャドウをさらに強めて差をつける。
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(
                    LinearGradient(
                        colors: [Self.neonGreen.opacity(developingPhotoCount > 0 ? 0.32 : 0.16), Color.black.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(
                    Self.neonGreen.opacity(developingPhotoCount > 0 ? (developingPulse ? 0.95 : 0.45) : 0.35),
                    lineWidth: developingPhotoCount > 0 ? 1.4 : 1
                )
            )
            // 現像中の写真がある間だけ、うっすら呼吸するように光量が上下するグロー。
            // 0枚の間も控えめな発光は常に残す。
            .shadow(
                color: Self.neonGreen.opacity(developingPhotoCount > 0 ? (developingPulse ? 0.6 : 0.2) : 0.12),
                radius: developingPhotoCount > 0 ? (developingPulse ? 10 : 5) : 3
            )
        }
        .buttonStyle(DevelopingButtonStyle())
        .onAppear { updateDevelopingPulse() }
        .onChange(of: developingPhotoCount) { _, _ in updateDevelopingPulse() }
    }

    /// developingPhotoCountが0→正になった/正→0になったタイミングで、無限リピートの
    /// パルスアニメーションを開始/停止する。単純にopacityの目標値をwithAnimation付きで
    /// 変えるだけで、.repeatForever(autoreverses: true)により自動的に往復し続ける。
    private func updateDevelopingPulse() {
        guard developingPhotoCount > 0 else {
            developingPulse = false
            return
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            developingPulse = true
        }
    }
}
