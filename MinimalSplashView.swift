import SwiftUI

/// 新しいミニマルなスプラッシュ画面
/// 太字グリーンの「later」ロゴと、タイムライン演出を含む洗練されたデザイン
struct MinimalSplashView: View {
    @State private var opacity: Double = 0
    @State private var dotPulse: Bool = false
    
    var body: some View {
        ZStack {
            // 深いダークチャコールブラック背景
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // メインロゴ：太字の「later」
                Text("later")
                    .font(.system(size: 72, weight: .black, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.6, blue: 0.4),  // ディープグリーン（上部）
                                Color(red: 0.3, green: 0.85, blue: 0.55)  // ライムグリーン（下部）
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.6), radius: 20, x: 0, y: 0)
                    .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.3), radius: 40, x: 0, y: 0)
                
                // タイムライン演出
                timelineView
            }
            .opacity(opacity)
        }
        .onAppear {
            // 1.5秒かけてゆっくりフェードイン
            withAnimation(.easeInOut(duration: 1.5)) {
                opacity = 1.0
            }
            
            // ドットのパルスアニメーション開始
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                dotPulse = true
            }
        }
    }
    
    // MARK: - タイムライン
    
    private var timelineView: some View {
        HStack(spacing: 0) {
            // グラデーションライン
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.6, blue: 0.4),   // ディープグリーン（左）
                    Color(red: 0.3, green: 0.85, blue: 0.55)   // ライムグリーン（右）
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 180, height: 2)
            
            // 終端ドット（パルスアニメーション）
            Circle()
                .fill(Color(red: 0.3, green: 0.85, blue: 0.55))
                .frame(width: 8, height: 8)
                .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.5).opacity(dotPulse ? 0.8 : 0.3), radius: dotPulse ? 12 : 6)
                .scaleEffect(dotPulse ? 1.2 : 1.0)
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview("ミニマルスプラッシュ") {
    MinimalSplashView()
}
