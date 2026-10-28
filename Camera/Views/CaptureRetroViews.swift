import SwiftUI
import AVKit

// MARK: - 撮影画面の色(この画面だけの値。既存の画面の色は変えない)

enum CaptureRetro {
    /// 橙(スタンプ・時刻)
    static let orange = Color(hex: "ff8a1f")
    /// 橙(アクセント:ダイヤルの灯・チップの縁・縁の文字)
    static let accent = Color(hex: "ffb27a")
    /// 場所チップの文字
    static let pale = Color(hex: "ffd9b8")
    /// 真珠(シャッターの玉)
    static let pearlLight = Color(hex: "e6e8ef")
    static let pearlShade = Color(hex: "9ca1b0")
    static let pearlDeep = Color(hex: "4b4f5c")
}

// MARK: - 動きの数式(撮影画面の長押しに合わせて見た目を決める)

enum CaptureMotion {
    /// 離したあと、ゲージがもどるまでの時間(秒)
    static let releaseDuration: TimeInterval = 0.3

    /// 離したあとの進み具合。離した時の値 from から、p×(1-k)² の形で0へもどる(k は 0〜1)。
    static func releasedProgress(from: Double, elapsed: TimeInterval, duration: TimeInterval = releaseDuration) -> Double {
        let k = min(1, max(0, elapsed / duration))
        return from * (1 - k) * (1 - k)
    }

    /// 絞りの穴の半径。p=0 では窓より大きく、見えない。p=1 で閉じる。
    static func apertureRadius(_ p: Double) -> Double {
        380 * pow(1 - p, 1.15)
    }

    /// 絞りの回転(ラジアン)。30° から p×0.36rad まわる。
    static func apertureRotation(_ p: Double) -> Double {
        30 * .pi / 180 + 0.36 * p
    }

    /// 光もれの濃さ
    static func lightLeakOpacity(_ p: Double) -> Double {
        0.7 * pow(p, 1.4)
    }

    /// 灯るダイヤルの目盛りの数(0〜60)
    static func litDialTicks(_ p: Double) -> Int {
        Int(floor(p * 60))
    }

    /// 真珠の大きさ(1 から 0.45 まで)
    static func pearlScale(_ p: Double) -> Double {
        1 - 0.55 * p
    }

    /// 日付スタンプの見え方
    static func stampOpacity(_ p: Double) -> Double {
        1 - 0.6 * p
    }

    /// 覗き窓の映像:明るさ・ぼかし・彩度
    static func previewBrightness(_ p: Double) -> Double { -0.45 * p }
    static func previewBlur(_ p: Double) -> Double { 5 * p }
    static func previewSaturation(_ p: Double) -> Double { 1.1 - 0.3 * p }

    /// ⑨の文言。長押しの途中だけ、進み具合で言い方を変える。
    static func holdCaption(progress p: Double, holding: Bool) -> String {
        guard holding else { return "1日3こままで。長押しで撮る" }
        return p < 0.35 ? "そのまま、持っていて" : "もうすぐ"
    }
}

// MARK: - 7セグメント表示(日付スタンプ・撮った時刻)

/// 7セグメントの数字・コロン・アポストロフィを、図形だけで描く(フォントは使わない)。
/// 消えている棒は不透明度7%で残す(液晶の雰囲気)。全体は斜め(-7°)。
struct SevenSegmentText: View {
    let text: String
    var height: CGFloat = 18
    var color: Color = CaptureRetro.orange

    private static let segmentsByDigit: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
    ]
    private static let segmentNames: [Character] = ["a", "b", "c", "d", "e", "f", "g"]
    /// 桁間 3.4 / コロン 4.8 / アポストロフィ 4.2 / 数字 10(高さ18を1単位とする)
    private static let gap: CGFloat = 3.4
    private static let slant = tan(-7 * CGFloat.pi / 180)

    var body: some View {
        Canvas { context, _ in
            let unit = height / 18
            context.concatenate(CGAffineTransform(a: 1, b: 0, c: Self.slant, d: 1, tx: 0, ty: 0))
            var x: CGFloat = 0
            for character in text {
                if let segments = Self.segmentsByDigit[character] {
                    Self.drawDigit(segments, at: x, unit: unit, into: &context, color: color)
                } else if character == ":" {
                    let dot = 2.2 * unit
                    let inset = (4.8 * unit - dot) / 2
                    for fraction in [0.33, 0.67] as [CGFloat] {
                        let rect = CGRect(x: x + inset, y: height * fraction - dot / 2, width: dot, height: dot)
                        context.fill(Path(rect), with: .color(color))
                    }
                } else if character == "'" {
                    let rect = CGRect(x: x, y: 0, width: 2 * unit, height: 5 * unit)
                    context.fill(Path(roundedRect: rect, cornerRadius: unit * 0.5), with: .color(color))
                }
                x += Self.advance(character, unit: unit) + Self.gap * unit
            }
        }
        .frame(width: width, height: height)
        .shadow(color: color.opacity(0.7), radius: 3)
        .accessibilityHidden(true)
    }

    private var width: CGFloat {
        let unit = height / 18
        let advances = text.reduce(CGFloat(0)) { $0 + Self.advance($1, unit: unit) }
        return advances + Self.gap * unit * CGFloat(max(0, text.count - 1))
    }

    private static func advance(_ character: Character, unit: CGFloat) -> CGFloat {
        if segmentsByDigit[character] != nil { return 10 * unit }
        if character == ":" { return 4.8 * unit }
        if character == "'" { return 4.2 * unit }
        return 6 * unit
    }

    private static func drawDigit(_ segments: String, at x: CGFloat, unit: CGFloat, into context: inout GraphicsContext, color: Color) {
        let w = 10 * unit
        let h = 18 * unit
        let t = 2.2 * unit
        let mid = h / 2
        let v = mid - 0.75 * t
        let rects: [Character: CGRect] = [
            "a": CGRect(x: x + t, y: 0, width: w - 2 * t, height: t),
            "b": CGRect(x: x + w - t, y: 0.5 * t, width: t, height: v),
            "c": CGRect(x: x + w - t, y: mid + 0.25 * t, width: t, height: v),
            "d": CGRect(x: x + t, y: h - t, width: w - 2 * t, height: t),
            "e": CGRect(x: x, y: mid + 0.25 * t, width: t, height: v),
            "f": CGRect(x: x, y: 0.5 * t, width: t, height: v),
            "g": CGRect(x: x + t, y: mid - t / 2, width: w - 2 * t, height: t),
        ]
        for name in segmentNames {
            guard let rect = rects[name] else { continue }
            let on = segments.contains(name)
            context.fill(
                Path(roundedRect: rect, cornerRadius: t * 0.3),
                with: .color(color.opacity(on ? 1 : 0.07))
            )
        }
    }
}

// MARK: - フォント(入っていなければ、システムの近い書体)

enum CaptureFonts {
    /// Space Mono Bold。入っていなければ、等幅の太字。
    static func monoBold(_ size: CGFloat) -> Font {
        if UIFont(name: "SpaceMono-Bold", size: size) != nil {
            return .custom("SpaceMono-Bold", size: size)
        }
        return .system(size: size, weight: .bold, design: .monospaced)
    }

    /// Inter Black。入っていなければ、システムの Heavy。
    static func interBlack(_ size: CGFloat) -> Font {
        if UIFont(name: "Inter-Black", size: size) != nil {
            return .custom("Inter-Black", size: size)
        }
        return .system(size: size, weight: .heavy)
    }
}

// MARK: - 数字ダイヤル(今日ののこり)

/// 右上の丸(直径40pt)。のこりの数字が減ると、縦の帯が上へ回る。
struct DigitDial: View {
    let value: Int
    let maxValue: Int

    private let diameter: CGFloat = 40

    var body: some View {
        let clamped = min(max(value, 0), maxValue)
        // 上から maxValue, …, 1, 0 の順に並べ、減ると帯が上へ動く
        VStack(spacing: 0) {
            ForEach(Array((0...maxValue).reversed()), id: \.self) { number in
                Text("\(number)")
                    .font(CaptureFonts.monoBold(18))
                    .foregroundStyle(Color(hex: "FF8A3D"))
                    .shadow(color: Color(hex: "FF6E14").opacity(0.85), radius: 6)
                    .frame(width: diameter, height: diameter)
            }
        }
        .offset(y: -CGFloat(maxValue - clamped) * diameter + CGFloat(maxValue) * diameter / 2)
        .animation(.spring(response: 0.55, dampingFraction: 0.6), value: clamped)
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .background(.ultraThinMaterial, in: Circle())
        .background(Circle().fill(.black.opacity(0.32)))
    }
}
