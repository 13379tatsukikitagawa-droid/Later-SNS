import SwiftUI

/// 起動直後、1秒間で完結する「ネオンレンズ・ダイブ」スプラッシュ演出。テキスト(ロゴ)は
/// 一切使わず、カメラのレンズをモチーフにしたリング1つだけで表現する。
/// Phase 1 [0.0-0.3s]: フォーカス・ロック(スケール2.0/不透明度0 → 1.0/1.0へ収束)
/// Phase 2 [0.3-0.5s]: シャッター発光(強いネオングロー+枠線が一瞬太くなる)
/// Phase 3 [0.5-1.0s]: ダイブ(リングが巨大化し、画面の奥へ迫るズームインで没入させる)
/// 1.0秒に達した時点でonFinishedを1回だけ呼ぶ。
struct MinimalSplashView: View {
    /// 1秒のシーケンスが完了した時点で1回だけ呼ばれる。呼び出し側はこれを合図に
    /// isSplashActiveをfalseにし、メイン画面へシームレスに切り替える。
    var onFinished: () -> Void = {}

    @State private var ringScale: CGFloat = 2.0
    @State private var ringOpacity: Double = 0
    @State private var ringLineWidth: CGFloat = 2
    @State private var ringGlowRadius: CGFloat = 0

    private let neonGreen = Color.brandGreen

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Circle()
                .stroke(neonGreen, lineWidth: ringLineWidth)
                .frame(width: 120, height: 120)
                .shadow(color: neonGreen.opacity(0.9), radius: ringGlowRadius)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
        }
        .onAppear { playSequence() }
    }

    private func playSequence() {
        // Phase 1 [0.0-0.3s]: フォーカス・ロック。ピントが合っていくように、
        // 大きく透明な状態から等倍・不透明へ収束させる。
        withAnimation(.easeOut(duration: 0.3)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }

        // Phase 2 [0.3-0.5s]: シャッター発光。強いグローと共に枠線が一瞬太くなり、
        // その直後にわずかに戻ってダイブへの溜めを作る。
        withAnimation(.easeOut(duration: 0.15).delay(0.3)) {
            ringGlowRadius = 20
            ringLineWidth = 6
        }
        withAnimation(.easeIn(duration: 0.05).delay(0.45)) {
            ringLineWidth = 4
        }

        // Phase 3 [0.5-1.0s]: ダイブ。リングが一気に巨大化し、画面の奥から手前へ
        // 迫ってその「中」を通り抜けるようなズームインの没入感を演出する。
        withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
            ringScale = 50.0
            ringOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onFinished()
        }
    }
}

// MARK: - Preview

#Preview("スプラッシュ") {
    MinimalSplashView()
}
