import SwiftUI

/// 🎊 写真解禁時のドラマチック演出
struct PhotoUnlockCelebration: View {
    let photoCount: Int
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -15
    @State private var particlesVisible = false
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 背景ブラー
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .opacity(opacity)
            
            VStack(spacing: 32) {
                // アイコン
                ZStack {
                    // 光のエフェクト
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.6),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 30)
                        .scaleEffect(scale * 1.5)
                    
                    // カメラアイコン
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.5),
                                    Color(red: 0.15, green: 0.6, blue: 0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.5), radius: 20)
                        .rotationEffect(.degrees(rotation))
                        .symbolEffect(.bounce, value: scale)
                }
                .scaleEffect(scale)
                
                VStack(spacing: 16) {
                    Text("現像完了！")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("\(photoCount)枚の写真が解禁されました")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Text("グループ投票が開始されます")
                        .font(.callout)
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.5))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.2))
                        )
                }
                .opacity(opacity)
                
                // 閉じるボタン
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isPresented = false
                    }
                } label: {
                    Text("投票を始める")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.05, green: 0.05, blue: 0.08))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.8, blue: 0.5))
                        )
                }
                .opacity(opacity)
            }
            
            // パーティクル
            if particlesVisible {
                ParticleSystem()
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // ハプティクス
        HapticsManager.unlockSuccess()
        
        // アニメーション開始
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
            rotation = 0
        }
        
        // パーティクル表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                particlesVisible = true
            }
        }
        
        // 追加のハプティクス
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticsManager.cardChange()
        }
    }
}

// MARK: - パーティクルシステム

struct ParticleSystem: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var velocity: CGPoint
    }
    
    @State private var canvasSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x,
                        y: particle.y,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(
                            Color(red: 0.2, green: 0.8, blue: 0.5)
                                .opacity(particle.opacity)
                        )
                    )
                }
            }
            .onAppear {
                canvasSize = geometry.size
                generateParticles()
                animateParticles()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private func generateParticles() {
        let width = canvasSize.width > 0 ? canvasSize.width : 400
        let height = canvasSize.height > 0 ? canvasSize.height : 800
        
        particles = (0..<50).map { _ in
            Particle(
                x: CGFloat.random(in: 0...width),
                y: height / 2,
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.6...1.0),
                velocity: CGPoint(
                    x: CGFloat.random(in: -3...3),
                    y: CGFloat.random(in: -8...(-3))
                )
            )
        }
    }
    
    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            for i in particles.indices {
                particles[i].x += particles[i].velocity.x
                particles[i].y += particles[i].velocity.y
                particles[i].velocity.y += 0.2 // 重力
                particles[i].opacity -= 0.01
            }
            
            particles.removeAll { $0.opacity <= 0 }
            
            if particles.isEmpty {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    PhotoUnlockCelebration(photoCount: 5, isPresented: .constant(true))
}
