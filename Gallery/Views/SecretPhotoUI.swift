import SwiftUI

// MARK: - Secret Photo Card (現像中UI)
/// 解禁前の写真カード - 完全秘匿デザイン
struct SecretPhotoCard: View {
    let status: SecretStatus
    var size: CGSize = CGSize(width: 350, height: 450)
    
    @State private var isAnimating = false
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            backgroundGradient
            
            // ぼかし効果の写真プレースホルダー
            blurredPhotoPlaceholder
            
            // 現像中オーバーレイ
            developingOverlay
            
            // ステータスメッセージ
            statusMessage
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Subviews
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.15),
                Color(red: 0.15, green: 0.1, blue: 0.2),
                Color(red: 0.1, green: 0.1, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // ノイズテクスチャ風
            Canvas { context, size in
                for _ in 0..<200 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.03))
                    )
                }
            }
        )
    }
    
    private var blurredPhotoPlaceholder: some View {
        GeometryReader { geometry in
            ZStack {
                // ランダムな色ブロック（ぼかしのベース）
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { col in
                                randomColorBlock(row: row, col: col)
                            }
                        }
                    }
                }
                .blur(radius: 50)
                .opacity(0.3)
                
                // 追加のぼかしレイヤー
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.05),
                                .clear,
                                .white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blur(radius: 30)
            }
        }
    }
    
    private func randomColorBlock(row: Int, col: Int) -> some View {
        let seed = row * 4 + col
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .cyan]
        return Rectangle()
            .fill(colors[seed % colors.count].opacity(0.4))
    }
    
    private var developingOverlay: some View {
        ZStack {
            // フィルムグレイン風エフェクト
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.9)
            
            // シマーエフェクト
            GeometryReader { geometry in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.1),
                                .white.opacity(0.2),
                                .white.opacity(0.1),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerPhase * geometry.size.width - geometry.size.width)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 2.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            shimmerPhase = 2
                        }
                    }
            }
            .opacity(0.6)
        }
    }
    
    private var statusMessage: some View {
        VStack(spacing: 20) {
            // アイコン
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .shadow(color: .white.opacity(0.2), radius: 10)
                
                Image(systemName: status.icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }
            
            VStack(spacing: 8) {
                // メインメッセージ
                Text(status.message)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                // サブメッセージ
                Text(status.submessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // プログレスインジケーター（数字なし）
            progressIndicator
        }
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 12) {
            // 無限ローディングバー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // プログレスバー
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.4, height: 4)
                        .offset(x: isAnimating ? geometry.size.width * 0.6 : -geometry.size.width * 0.4)
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 4)
            .frame(maxWidth: 200)
            
            // 待機メッセージ（時間情報なし）
            HStack(spacing: 6) {
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(0),
                        value: isAnimating
                    )
                
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(0.2),
                        value: isAnimating
                    )
                
                Circle()
                    .fill(.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(0.4),
                        value: isAnimating
                    )
            }
            .padding(.top, 8)
        }
    }
    
    private func startAnimations() {
        isAnimating = true
    }
}

// MARK: - Secret Status

enum SecretStatus {
    case developing          // 現像中
    case waitingForReveal    // 一斉解禁待機中
    case userNotReady        // 自分が未完了
    
    var icon: String {
        switch self {
        case .developing:
            return "photo.fill.on.rectangle.fill"
        case .waitingForReveal:
            return "hourglass"
        case .userNotReady:
            return "camera.fill"
        }
    }
    
    var message: String {
        switch self {
        case .developing:
            return "現像中..."
        case .waitingForReveal:
            return "次の一斉解禁を待機中"
        case .userNotReady:
            return "目標枚数を撮影してください"
        }
    }
    
    var submessage: String {
        switch self {
        case .developing:
            return "全ユーザー共通のタイミングで解禁されます"
        case .waitingForReveal:
            return "みんなで同じ瞬間に写真が解禁されます"
        case .userNotReady:
            return "撮影完了後、解禁タイミングで閲覧できます"
        }
    }
}

// MARK: - Feed Lock Overlay (フィード全体用)

struct FeedSecretOverlay: View {
    let status: SecretStatus
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // メインアイコン
                ZStack {
                    // 外側の輪
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0 : 0.6)
                    
                    // 内側の円
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .shadow(color: .blue.opacity(0.5), radius: 20)
                    
                    // アイコン
                    Image(systemName: status.icon)
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)
                }
                .onAppear {
                    withAnimation(
                        .easeOut(duration: 2)
                        .repeatForever(autoreverses: false)
                    ) {
                        isAnimating = true
                    }
                }
                
                // メッセージ
                VStack(spacing: 16) {
                    Text(status.message)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text(status.submessage)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // 注意書き
                    Text("※ 時間表示はありません。お楽しみに！")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // 装飾的なプログレスバー
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.1))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple, .pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * 0.3, height: 6)
                                .offset(x: isAnimating ? geometry.size.width * 0.7 : -geometry.size.width * 0.3)
                                .animation(
                                    .linear(duration: 2)
                                    .repeatForever(autoreverses: false),
                                    value: isAnimating
                                )
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 250)
                    
                    Text("準備が整い次第、通知でお知らせします")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Mini Status Badge (小さいステータス表示)

struct SecretStatusBadge: View {
    let status: SecretStatus
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.caption.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating)
            
            Text(status.message)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        .scaleEffect(isPulsing ? 1.05 : 1.0)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Secret Photo Card - Developing") {
    ZStack {
        Color.black.ignoresSafeArea()
        SecretPhotoCard(status: .developing)
    }
}

#Preview("Secret Photo Card - Waiting") {
    ZStack {
        Color.black.ignoresSafeArea()
        SecretPhotoCard(status: .waitingForReveal)
    }
}

#Preview("Secret Photo Card - User Not Ready") {
    ZStack {
        Color.black.ignoresSafeArea()
        SecretPhotoCard(status: .userNotReady)
    }
}

#Preview("Feed Secret Overlay") {
    FeedSecretOverlay(status: .waitingForReveal)
}

#Preview("Secret Status Badge") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            SecretStatusBadge(status: .developing)
            SecretStatusBadge(status: .waitingForReveal)
            SecretStatusBadge(status: .userNotReady)
        }
    }
}
