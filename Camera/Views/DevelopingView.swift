import SwiftUI
import SwiftUI
import CoreImage.CIFilterBuiltins
internal import Combine

public struct DevelopingView: View {
    private let image: UIImage
    private let lockAt: Date
    private let unlockAt: Date

    @State private var now: Date = .now
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    public init(image: UIImage, lockAt: Date, unlockAt: Date) {
        self.image = image
        self.lockAt = lockAt
        self.unlockAt = unlockAt
    }

    private var progress: Double {
        let total = unlockAt.timeIntervalSince(lockAt)
        guard total > 0 else { return 1 }
        let p = (now.timeIntervalSince(lockAt)) / total
        return min(max(p, 0), 1)
    }

    // MARK: - Stage parameters

    private var blur: CGFloat {
        switch progress {
        case 0..<0.3:
            // 20 -> 10
            let t = progress / 0.3
            return CGFloat(20 - 10 * t)
        case 0.3..<0.7:
            // 10 -> 4
            let t = (progress - 0.3) / 0.4
            return CGFloat(10 - 6 * t)
        case 0.7..<1.0:
            // 4 -> 0
            let t = (progress - 0.7) / 0.3
            return CGFloat(4 * (1 - t))
        default:
            return 0
        }
    }

    private var grayscale: Double {
        switch progress {
        case 0..<0.3:
            return 1.0
        case 0.3..<0.7:
            return 1.0
        case 0.7..<1.0:
            let t = (progress - 0.7) / 0.3
            return 1.0 - t
        default:
            return 0
        }
    }

    private var saturation: Double {
        switch progress {
        case 0..<0.7:
            return 0.0
        case 0.7..<1.0:
            let t = (progress - 0.7) / 0.3
            return t
        default:
            return 1.0
        }
    }

    private var darknessOpacity: Double {
        switch progress {
        case 0..<0.3:
            // 0.6 -> 0.4
            let t = progress / 0.3
            return 0.6 - 0.2 * t
        case 0.3..<0.7:
            // 0.4 -> 0.2
            let t = (progress - 0.3) / 0.4
            return 0.4 - 0.2 * t
        case 0.7..<1.0:
            // 0.2 -> 0
            let t = (progress - 0.7) / 0.3
            return 0.2 * (1 - t)
        default:
            return 0
        }
    }

    private var noiseAmount: Double {
        switch progress {
        case 0..<0.3:
            return 1.0
        case 0.3..<0.7:
            return 0.5
        case 0.7..<1.0:
            let t = (progress - 0.7) / 0.3
            return 0.5 * (1 - t)
        default:
            return 0
        }
    }

    public var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .saturation(saturation)
                .grayscale(grayscale)
                .blur(radius: blur)
                .animation(.easeInOut(duration: 0.6), value: blur)
                .animation(.easeInOut(duration: 0.6), value: grayscale)
                .animation(.easeInOut(duration: 0.6), value: saturation)

            // Darkness overlay
            Color.black.opacity(darknessOpacity)
                .animation(.easeInOut(duration: 0.6), value: darknessOpacity)

            // Noise overlay
            NoiseView()
                .opacity(noiseAmount)
                .animation(.easeInOut(duration: 0.6), value: noiseAmount)

            // Ripple overlay with text when progress < 1
            if progress < 1 {
                RippleOverlay()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .overlay(
                        VStack {
                            Text("現像中...")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 0)
                        }
                    )
            }
        }
        .onReceive(timer) { time in
            now = time
        }
    }
}

// MARK: - NoiseView

fileprivate struct NoiseView: View {
    @State private var noiseSeed = UUID()
    @State private var animate = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0, paused: false)) { (context: TimelineViewDefaultContext) in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                let scale = 0.02
                var path = Path()

                for y in stride(from: 0, to: Int(size.height), by: 4) {
                    for x in stride(from: 0, to: Int(size.width), by: 4) {
                        let noise = perlinNoise(x: Double(x) * scale, y: Double(y) * scale, time: time)
                        let alpha = 0.06 + 0.1 * noise
                        if alpha > 0.07 {
                            path.addEllipse(in: CGRect(x: CGFloat(x), y: CGFloat(y), width: 1.5, height: 1.5))
                        }
                    }
                }

                ctx.fill(path, with: .color(.white.opacity(0.08)))
            }
            .drawingGroup()
            .blendMode(.screen)
        }
    }

    // Simple Perlin noise approximation
    private func perlinNoise(x: Double, y: Double, time: Double) -> Double {
        let s = sin(x * 10 + time * 3) * cos(y * 10 - time * 2)
        return (s + 1) / 2
    }
}

// MARK: - RippleOverlay

fileprivate struct RippleOverlay: View {
    private let rippleCount = 3
    private let rippleDuration: Double = 1.8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0, paused: false)) { (context: TimelineViewDefaultContext) in
            let now = context.date.timeIntervalSinceReferenceDate

            ZStack {
                ForEach(0..<rippleCount, id: \.self) { i in
                    let progress = ((now - Double(i) * rippleDuration / Double(rippleCount)).truncatingRemainder(dividingBy: rippleDuration)) / rippleDuration
                    if progress >= 0 {
                        Circle()
                            .stroke(Color.white.opacity(1 - progress), lineWidth: 3)
                            .scaleEffect(0.7 + CGFloat(progress) * 1.3)
                            .opacity(1 - progress)
                            .animation(nil, value: progress)
                    }
                }
            }
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

struct DevelopingView_Previews: PreviewProvider {
    static var previews: some View {
        let image: UIImage = {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
            return renderer.image { ctx in
                UIColor.blue.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
                let config = UIImage.SymbolConfiguration(pointSize: 120, weight: .bold)
                let symbol = UIImage(systemName: "photo.fill", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
                symbol?.draw(at: CGPoint(x: 90, y: 90))
            }
        }()

        let now = Date()
        let lockAt = now.addingTimeInterval(-10) // 10 seconds ago
        let unlockAt = now.addingTimeInterval(20) // 20 seconds from now

        DevelopingView(image: image, lockAt: lockAt, unlockAt: unlockAt)
            .frame(width: 300, height: 300)
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
