import SwiftUI
import UIKit
internal import Combine

// MARK: - Darkroom Transition Modifier
/// 暗室で写真を手で分けるような奥行きのあるトランジション

struct DarkroomTransition: ViewModifier {
    let isActive: Bool
    @State private var dragOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(Double(dragOffset) * 0.3),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .offset(x: dragOffset)
            .scaleEffect(isActive ? 0.95 : 1.0)
            .opacity(isActive ? 0.7 : 1.0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
            )
    }
}

// MARK: - Photo Hanging Transition
/// 吊るされた写真を手で分けるようなトランジション効果

struct PhotoHangingTransition: GeometryEffect {
    var progress: Double
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        // 写真が吊るされて揺れるような動き
        let angle = sin(progress * .pi) * 15.0 // 最大15度の回転
        let translation = CGAffineTransform(translationX: 0, y: -size.height * (1.0 - progress))
        let rotation = CGAffineTransform(rotationAngle: angle * .pi / 180)
        
        return ProjectionTransform(translation.concatenating(rotation))
    }
}

// MARK: - Developing Progress Animation
/// 現像進捗に応じた段階的エフェクト解除アニメーション

struct DevelopingProgressModifier: ViewModifier {
    let progress: Double // 0.0 〜 1.0
    
    // エフェクトの強度を段階的に計算
    private var blurAmount: CGFloat {
        let maxBlur: CGFloat = 40
        return maxBlur * (1.0 - easeOutCubic(progress))
    }
    
    private var grayscaleAmount: Double {
        1.0 - easeInQuad(progress)
    }
    
    private var overlayOpacity: Double {
        0.6 * (1.0 - easeOutQuad(progress))
    }
    
    func body(content: Content) -> some View {
        content
            .blur(radius: blurAmount)
            .grayscale(grayscaleAmount)
            .overlay {
                Rectangle()
                    .fill(.white)
                    .opacity(overlayOpacity)
                    .allowsHitTesting(false)
            }
            .overlay {
                if progress < 0.3 {
                    // 現像初期: ノイズエフェクト
                    NoiseTexture()
                        .opacity((0.3 - progress) / 0.3 * 0.4)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if progress < 0.5 {
                    // 現像中期: 化学薬品の波紋エフェクト
                    ChemicalWavesView()
                        .opacity((0.5 - progress) / 0.5 * 0.3)
                        .allowsHitTesting(false)
                }
            }
    }
    
    // MARK: - Easing Functions
    
    private func easeOutCubic(_ t: Double) -> Double {
        let p = t - 1
        return p * p * p + 1
    }
    
    private func easeInQuad(_ t: Double) -> Double {
        return t * t
    }
    
    private func easeOutQuad(_ t: Double) -> Double {
        return t * (2 - t)
    }
}

// MARK: - Noise Texture

struct NoiseTexture: View {
    @State private var phase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/15)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let seed = Int(now * 10) % 10000
                
                drawNoise(context: context, size: size, seed: seed)
            }
        }
    }
    
    private func drawNoise(context: GraphicsContext, size: CGSize, seed: Int) {
        let dotSize: CGFloat = 3
        let columns = Int(size.width / dotSize)
        let rows = Int(size.height / dotSize)
        
        for row in 0..<rows {
            for col in 0..<columns {
                let random = Double((seed + row * columns + col) % 100) / 100.0
                
                if random > 0.7 {
                    let x = CGFloat(col) * dotSize
                    let y = CGFloat(row) * dotSize
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(random * 0.8))
                    )
                }
            }
        }
    }
}

// MARK: - Chemical Waves View

struct ChemicalWavesView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let angle = CGFloat(now.truncatingRemainder(dividingBy: 4 * .pi))
                
                drawChemicalWaves(context: context, size: size, phase: angle)
            }
        }
    }
    
    private func drawChemicalWaves(context: GraphicsContext, size: CGSize, phase: CGFloat) {
        let numCircles = 8
        let maxRadius = max(size.width, size.height) * 0.7
        
        for i in 0..<numCircles {
            let progress = CGFloat(i) / CGFloat(numCircles)
            let radius = maxRadius * progress + phase * 20
            let opacity = 0.15 * (1.0 - progress)
            
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let circlePath = Circle().path(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            
            context.stroke(
                circlePath,
                with: .color(.white.opacity(opacity)),
                lineWidth: 2
            )
        }
    }
}

// MARK: - Swipe Gesture Handler

class SwipeGestureHandler: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var offset: CGFloat = 0
    @Published var isDragging: Bool = false
    
    let totalItems: Int
    let threshold: CGFloat = 50
    
    init(totalItems: Int) {
        self.totalItems = totalItems
    }
    
    func handleDragChanged(_ value: DragGesture.Value) {
        isDragging = true
        offset = value.translation.width
    }
    
    func handleDragEnded(_ value: DragGesture.Value) {
        isDragging = false
        
        let predictedEnd = value.predictedEndTranslation.width
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if predictedEnd < -threshold && currentIndex < totalItems - 1 {
                // 次の写真へ
                currentIndex += 1
                offset = 0
                
                // ハプティック
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else if predictedEnd > threshold && currentIndex > 0 {
                // 前の写真へ
                currentIndex -= 1
                offset = 0
                
                // ハプティック
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else {
                // 元に戻す
                offset = 0
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func darkroomTransition(isActive: Bool = false) -> some View {
        modifier(DarkroomTransition(isActive: isActive))
    }
    
    func developingProgress(_ progress: Double) -> some View {
        modifier(DevelopingProgressModifier(progress: progress))
    }
}

// MARK: - Preview

#if DEBUG
struct NoiseTexture_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NoiseTexture()
                .opacity(0.5)
        }
        .previewDisplayName("Noise Texture")
    }
}

struct ChemicalWavesView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ChemicalWavesView()
        }
        .previewDisplayName("Chemical Waves")
    }
}

struct DevelopingProgress_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ForEach([0.0, 0.3, 0.5, 0.7, 1.0], id: \.self) { progress in
                DevelopingProgressItem(progress: progress)
            }
        }
        .padding()
        .background(.gray)
        .previewDisplayName("Developing Progress")
    }
    
    struct DevelopingProgressItem: View {
        let progress: Double
        
        var body: some View {
            if let image = UIImage(systemName: "photo.fill") {
                let progressInt = Int(progress * 100)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .developingProgress(progress)
                    .overlay(alignment: .bottom) {
                        Text("Progress: \(progressInt)%")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.7))
                    }
            }
        }
    }
}
#endif
