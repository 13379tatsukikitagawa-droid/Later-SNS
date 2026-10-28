import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MARK: - 現像の濃さ

/// 撮った時刻 → 次の9:00 を t(0〜1)とし、現像の濃さは d = t^0.75。
/// 見た目だけの進行で、解禁の判定には使わない。
enum DevelopDensity {
    static let exponent = 0.75
    /// 1時間に1個灯る点の数(撮影から次の9:00まで、最大24個)
    static let dotCount = 24

    static func fraction(capturedAt t0: Date, now: Date) -> Double {
        let t1 = DevelopProgress.finishDate(capturedAt: t0)
        let span = t1.timeIntervalSince(t0)
        guard span > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(t0) / span))
    }

    static func density(_ t: Double) -> Double {
        pow(min(1, max(0, t)), exponent)
    }

    /// 撮影からの経過時間ぶん灯る点の数(いまの時間の点を含む。1〜24)
    static func litDots(capturedAt t0: Date, now: Date) -> Int {
        let hours = Int(max(0, now.timeIntervalSince(t0)) / 3600)
        return min(dotCount, hours + 1)
    }

    /// 次の9:00までの残り(「23:44」)
    static func remainingText(capturedAt t0: Date, now: Date) -> String {
        let finish = DevelopProgress.finishDate(capturedAt: t0)
        let minutes = max(0, Int(finish.timeIntervalSince(now) / 60))
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

// MARK: - ぼかした色だけの画像

/// 現像カード・現像シートに渡す「強くぼかした色だけ」の小さな画像を作る。
/// 元の画像・高解像度の画像はViewに渡さない(ここで縮小とぼかしを済ませてから渡す)。
enum DevelopTexture {
    private static let cache = NSCache<NSString, UIImage>()
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func cached(key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// 32px角まで縮小して、強くぼかす。
    static func make(from data: Data?, key: String) async -> UIImage? {
        if let hit = cached(key: key) { return hit }
        guard let data, !data.isEmpty else { return nil }
        let image = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let source = CIImage(data: data) else { return nil }
            let side: CGFloat = 32
            let scale = side / max(source.extent.width, source.extent.height)
            let small = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = small.clampedToExtent()
            blur.radius = 3.5
            guard let output = blur.outputImage?.cropped(to: small.extent),
                  let cg = ciContext.createCGImage(output, from: output.extent) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        if let image { cache.setObject(image, forKey: key as NSString) }
        return image
    }
}

// MARK: - チェキ現像の見た目

/// 写真の中身は、ずっとぼかしたまま。見えるのは「色」と「濃さ」だけ。
/// 乳白色のもや(青みがかった灰白)が、濃さ d とともに晴れて色が濃くなる。
struct ChekiDevelopImage: View {
    /// 強くぼかした小さな画像(DevelopTexture)。nilなら代表色だけで描く
    let texture: UIImage?
    var tones: [Color] = DevelopProgress.defaultTones
    /// 濃さ d(0〜1)
    let density: Double
    /// 現像シートのプリント(もやの中の雲・縁の暗がりを足す)
    var isSheet = false
    /// ぼかしの強さの倍率(カードの小さな丸は小さくする)
    var blurScale: CGFloat = 1
    var isAnimating = true

    var body: some View {
        let d = min(1, max(0, density))
        ZStack {
            photo(d)
            // 乳白色のもや
            LinearGradient(colors: [Color(hex: "D3E0D8"), Color(hex: "BFD0E0")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(pow(1 - d, 0.8) * 0.94)
            if isSheet {
                clouds(d)
                RadialGradient(colors: [.clear, .black.opacity(0.35 * d)], center: .center, startRadius: 40, endRadius: 150)
            }
        }
        .clipped()
    }

    private func photo(_ d: Double) -> some View {
        Group {
            if let texture {
                Image(uiImage: texture)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                toneField
            }
        }
        .blur(radius: ((1 - d) * 4 + 4) * blurScale)
        .saturation(0.2 + 1.05 * d)
        .contrast(0.7 + 0.4 * d)
        .brightness(-(0.15 - 0.15 * d))
        .scaleEffect(1.15)
    }

    private var toneField: some View {
        let colors = tones.count >= 3 ? Array(tones.prefix(3)) : DevelopProgress.defaultTones
        return GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                colors[2]
                Circle().fill(colors[0]).frame(width: w * 0.9).offset(x: -w * 0.2, y: -h * 0.25)
                Circle().fill(colors[1]).frame(width: w * 0.8).offset(x: w * 0.25, y: h * 0.2)
            }
            .frame(width: w, height: h)
            .blur(radius: w * 0.18)
        }
    }

    /// もやの中を、うすい白い雲がゆっくり動く(周期9秒・12秒)
    private func clouds(_ d: Double) -> some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                ZStack {
                    Ellipse().fill(.white)
                        .frame(width: w * 0.9, height: h * 0.4)
                        .offset(x: w * 0.25 * sin(2 * .pi * t / 9), y: -h * 0.18)
                    Ellipse().fill(.white)
                        .frame(width: w * 0.8, height: h * 0.35)
                        .offset(x: -w * 0.25 * sin(2 * .pi * t / 12 + 1), y: h * 0.22)
                }
                .frame(width: w, height: h)
                .blur(radius: 18)
                .opacity(pow(1 - d, 1.1) * 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 24個の点(1時間に1個)

/// 現像の点。12時の位置から時計まわりに、1時間に1個灯る。いまの時間の点だけ大きく光って脈打つ。
struct DevelopDots {
    /// 0...23 の点の見た目
    struct Dot {
        var radius: CGFloat
        var color: Color
        var glow: Bool
    }

    static func dot(index: Int, lit: Int, isDeveloped: Bool, pulse: Double, baseRadius: CGFloat = 2) -> Dot {
        if isDeveloped {
            return Dot(radius: baseRadius * 1.1, color: Color(hex: "FFD9C2"), glow: true)
        }
        guard index < lit else {
            return Dot(radius: 1.4, color: .white.opacity(0.2), glow: false)
        }
        if index == lit - 1 {
            return Dot(radius: baseRadius * 1.5 * (1 + 0.15 * pulse), color: HomePalette.orange, glow: true)
        }
        // 古いほどうすい(0.3 → 0.85)
        let age = lit <= 1 ? 1 : Double(index) / Double(lit - 1)
        return Dot(radius: baseRadius, color: HomePalette.orange.opacity(0.3 + 0.55 * age), glow: false)
    }

    /// 2.2秒周期の脈(0〜1)
    static func pulse(_ t: Double) -> Double {
        0.5 + 0.5 * sin(2 * .pi * t / 2.2)
    }
}

/// 円に24個の点を並べたリング
struct DevelopDotRing: View {
    let lit: Int
    let isDeveloped: Bool
    var diameter: CGFloat = 68
    var radius: CGFloat = 31
    var isAnimating = true

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            let pulse = DevelopDots.pulse(context.date.timeIntervalSinceReferenceDate)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<DevelopDensity.dotCount {
                    let angle = -Double.pi / 2 + Double(i) / Double(DevelopDensity.dotCount) * 2 * .pi
                    let p = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
                    let dot = DevelopDots.dot(index: i, lit: lit, isDeveloped: isDeveloped, pulse: pulse)
                    if dot.glow {
                        var g = ctx
                        g.addFilter(.blur(radius: dot.radius * 1.4))
                        g.fill(Path(ellipseIn: CGRect(x: p.x - dot.radius * 1.8, y: p.y - dot.radius * 1.8, width: dot.radius * 3.6, height: dot.radius * 3.6)), with: .color(dot.color.opacity(0.6)))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - dot.radius, y: p.y - dot.radius, width: dot.radius * 2, height: dot.radius * 2)), with: .color(dot.color))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
