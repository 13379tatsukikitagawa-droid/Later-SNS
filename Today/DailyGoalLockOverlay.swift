import SwiftUI

/// 🔒 目標達成時に表示される「撮影完了・ロック」演出オーバーレイ
struct DailyGoalLockOverlay: View {
    let photosTaken: Int
    let goal: Int
    var onComplete: () -> Void
    
    @State private var showLock = false
    @State private var lockScale: CGFloat = 0.3
    @State private var lockRotation: Double = -90
    @State private var lockOpacity: Double = 0
    
    @State private var showMessage = false
    @State private var messageScale: CGFloat = 0.5
    @State private var messageOpacity: Double = 0
    
    @State private var darkOverlayOpacity: Double = 0
    @State private var grainOpacity: Double = 0
    
    @State private var showParticles = false
    
    var body: some View {
        ZStack {
            // 1. ダークフィルター
            Color.black
                .opacity(darkOverlayOpacity)
                .ignoresSafeArea()
            
            // 2. グレイン（フィルム現像風）
            FilmGrainView()
                .opacity(grainOpacity)
                .ignoresSafeArea()
                .blendMode(.overlay)
            
            // 3. パーティクルエフェクト
            if showParticles {
                ParticleEffectView()
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // 4. 南京錠アイコン
                ZStack {
                    // 後光エフェクト
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.brandGreen.opacity(0.3),
                                    Color.brandGreen.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(lockScale * 1.2)
                        .opacity(lockOpacity)
                    
                    // 錠前アイコン
                    Image(systemName: "lock.fill")
                        .font(.system(size: 100, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.brandGreen, Color.brandGreen.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.brandGreen.opacity(0.6), radius: 30, x: 0, y: 10)
                        .scaleEffect(lockScale)
                        .rotationEffect(.degrees(lockRotation))
                        .opacity(lockOpacity)
                }
                .opacity(showLock ? 1 : 0)
                
                // 5. メインメッセージ
                VStack(spacing: 16) {
                    Text("MISSION COMPLETE")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.brandGreen.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.brandGreen.opacity(0.5), radius: 10, x: 0, y: 5)
                        .multilineTextAlignment(.center)
                    
                    Text("今日の思い出は全て封印されました")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    // 統計バッジ
                    HStack(spacing: 20) {
                        CompletionBadge(icon: "camera.fill", value: "\(photosTaken)")
                        CompletionBadge(icon: "checkmark.seal.fill", value: "\(goal)")
                    }
                    .padding(.top, 8)
                    
                    Text("解禁までお楽しみに...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 8)
                }
                .scaleEffect(messageScale)
                .opacity(messageOpacity)
                .opacity(showMessage ? 1 : 0)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - アニメーション制御
    
    private func startAnimation() {
        // 0. 触覚フィードバック（重い衝撃）
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        heavyImpact.impactOccurredIfEnabled()
        
        // 1. ダークオーバーレイをフェードイン (0-0.3秒)
        withAnimation(.easeIn(duration: 0.3)) {
            darkOverlayOpacity = 0.85
        }
        
        // 2. 南京錠を表示 (0.2-0.8秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showLock = true
            
            // ロック回転＆スケールアニメーション
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                lockScale = 1.0
                lockRotation = 0
                lockOpacity = 1.0
            }
            
            // ロック音の代わりにハプティクス
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurredIfEnabled(.success)
        }
        
        // 3. グレインエフェクトを追加 (0.5秒-)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.4)) {
                grainOpacity = 0.15
            }
        }
        
        // 4. パーティクル開始 (0.6秒-)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showParticles = true
        }
        
        // 5. メッセージ表示 (0.8-1.4秒)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showMessage = true
            
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                messageScale = 1.0
                messageOpacity = 1.0
            }
            
            // 追加ハプティクス
            let lightImpact = UIImpactFeedbackGenerator(style: .light)
            lightImpact.impactOccurredIfEnabled()
        }
        
        // 6. 自動遷移 (3.5秒後)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                darkOverlayOpacity = 0
                lockOpacity = 0
                messageOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }
}

// MARK: - サブビュー

/// 完了バッジ
struct CompletionBadge: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color.brandGreen)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.brandGreen.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.brandGreen.opacity(0.4), lineWidth: 2)
        )
    }
}

/// フィルムグレイン効果
struct FilmGrainView: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // シンプルなノイズパターン生成
                for _ in 0..<500 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.3)))
                }
            }
        }
    }
}

/// パーティクルエフェクト（光の粒）
struct ParticleEffectView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                animateParticles()
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        particles = (0..<30).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: size.height * 0.3...size.height * 0.7)
                ),
                size: CGFloat.random(in: 3...8),
                color: [Color.brandGreen, Color.white, Color.brandGreen.opacity(0.7)].randomElement()!,
                opacity: Double.random(in: 0.3...0.8)
            )
        }
    }
    
    private func animateParticles() {
        withAnimation(.easeOut(duration: 2.0)) {
            for i in particles.indices {
                particles[i].opacity = 0
                particles[i].position.y -= CGFloat.random(in: 100...200)
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let size: CGFloat
    let color: Color
    var opacity: Double
}

// MARK: - Preview

#if DEBUG
struct DailyGoalLockOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.brandBlack.ignoresSafeArea()
            
            DailyGoalLockOverlay(photosTaken: 3, goal: 3) {
                print("Animation complete")
            }
        }
    }
}
#endif
