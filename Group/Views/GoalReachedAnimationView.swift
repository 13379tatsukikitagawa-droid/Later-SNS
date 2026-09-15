import SwiftUI

/// 目標撮影枚数(MEまたはGroup、shotCount >= targetCount)を達成した瞬間に、画面全体の
/// 最前面へ一度だけ再生するお祝いオーバーレイ。ネオングリーン基調のサイバーパンク調で、
/// 「粒子爆発 → ネオン文字現出 → デジタルグリッド → フェードアウト」の4フェーズを
/// 内部で自走式に進行し、終わったらonCompletedを呼んで自分自身を閉じる(呼び出し側は
/// 表示フラグをfalseに戻すだけでよい)。
struct GoalReachedAnimationView: View {
    var onCompleted: () -> Void

    @State private var particles: [GoalBurstParticle] = GoalBurstParticle.generate(count: 30)
    @State private var burstProgress: CGFloat = 0
    @State private var flashScale: CGFloat = 0.3
    @State private var flashOpacity: Double = 0
    @State private var textScale: CGFloat = 0.3
    @State private var textOpacity: Double = 0
    @State private var gridMaskProgress: CGFloat = 0
    @State private var isFadingOut = false

    private static let neonGreen = Color.brandGreen

    var body: some View {
        ZStack {
            Color.black.opacity(0.86)

            digitalGrid

            particleBurst

            flashCore

            goalText
        }
        .ignoresSafeArea()
        .opacity(isFadingOut ? 0 : 1)
        .allowsHitTesting(false)
        .onAppear { playSequence() }
    }

    // MARK: - Phase 1: 中心の発光フラッシュ+粒子爆発

    private var flashCore: some View {
        Circle()
            .fill(Self.neonGreen)
            .frame(width: 40, height: 40)
            .blur(radius: 22)
            .scaleEffect(flashScale)
            .opacity(flashOpacity)
    }

    private var particleBurst: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Self.neonGreen)
                        .frame(width: particle.size, height: particle.size)
                        .blur(radius: particle.blur)
                        .opacity(particle.baseOpacity * Double(1 - burstProgress))
                        .position(
                            x: center.x + cos(particle.angle) * particle.distance * burstProgress,
                            y: center.y + sin(particle.angle) * particle.distance * burstProgress
                        )
                }
            }
        }
    }

    // MARK: - Phase 2: ネオン文字

    private var goalText: some View {
        VStack(spacing: 10) {
            Text("GOAL ACHIEVED")
                .font(.custom("Courier New", size: 34).weight(.bold))
                .tracking(2)
                .foregroundStyle(Self.neonGreen)
                .shadow(color: Self.neonGreen.opacity(0.95), radius: 14)
                .shadow(color: Self.neonGreen.opacity(0.6), radius: 28)

            Text("目標達成！")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: Self.neonGreen.opacity(0.5), radius: 8)
        }
        .scaleEffect(textScale)
        .opacity(textOpacity)
    }

    // MARK: - Phase 3: デジタルグリッドのゲート

    private var digitalGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var x: CGFloat = 0
            while x <= size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Self.neonGreen.opacity(0.28)), lineWidth: 1)
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Self.neonGreen.opacity(0.28)), lineWidth: 1)
                y += spacing
            }
        }
        .mask(
            GeometryReader { geometry in
                Rectangle()
                    .frame(width: geometry.size.width * gridMaskProgress, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        )
    }

    // MARK: - シーケンス進行

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }

    private func playSequence() {
        Task { @MainActor in
            // Phase 1: 粒子爆発(0〜0.5秒)。目標ゲージが発光してから弾けるイメージで、
            // 中心のフラッシュを粒子の拡散と同時に走らせる。
            withAnimation(.easeOut(duration: 0.3)) {
                flashScale = 3.2
                flashOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5)) {
                burstProgress = 1
            }
            withAnimation(.easeIn(duration: 0.45)) {
                flashOpacity = 0
            }

            await sleep(0.3)

            // Phase 2: ネオン文字現出(0.3〜1.0秒)。拡大しながら浮かび上がり、
            // ネオンサイン特有の明滅を数回はさんでから点灯安定させる。
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                textScale = 1.0
            }
            textOpacity = 1
            await flickerText()

            await sleep(0.3)

            // Phase 3: デジタルグリッドのゲート(1.0〜1.5秒)。中心から左右へ開くように
            // マスクの幅を0→100%へアニメーションする。
            withAnimation(.easeInOut(duration: 0.5)) {
                gridMaskProgress = 1
            }

            await sleep(0.5)

            // Phase 4: フェードアウト(1.5〜2.5秒)。全体をゆっくり消してから閉じる。
            withAnimation(.easeInOut(duration: 1.0)) {
                isFadingOut = true
            }

            await sleep(1.0)

            onCompleted()
        }
    }

    private func flickerText() async {
        for opacity in [0.25, 1.0, 0.35, 1.0, 0.55, 1.0] {
            withAnimation(.easeInOut(duration: 0.06)) {
                textOpacity = opacity
            }
            await sleep(0.06)
        }
        withAnimation(.easeInOut(duration: 0.1)) {
            textOpacity = 1.0
        }
    }
}

// MARK: - 粒子

private struct GoalBurstParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let baseOpacity: Double
    let blur: CGFloat

    static func generate(count: Int) -> [GoalBurstParticle] {
        (0..<count).map { _ in
            GoalBurstParticle(
                angle: Double.random(in: 0..<(2 * .pi)),
                distance: CGFloat.random(in: 90...240),
                size: CGFloat.random(in: 3...8),
                baseOpacity: Double.random(in: 0.5...1.0),
                blur: CGFloat.random(in: 0...1.5)
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GoalReachedAnimationView(onCompleted: {})
    }
}
