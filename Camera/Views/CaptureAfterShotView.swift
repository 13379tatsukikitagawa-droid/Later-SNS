import SwiftUI

// MARK: - 撮ったあとのアニメ(フィルムを巻く・文字なし)

/// 撮ったあとの画面の、ある時刻の状態。すべて 0〜1 の見え方と、巻いた量(pt)・回転(度)。
struct CaptureAfterShotFrame: Equatable {
    /// 白いフラッシュの濃さ
    var flash: Double
    /// 撮影の部品(戻る・チップ・ダイヤル・文言)の見え方
    var chrome: Double
    /// 覗き窓の見え方
    var window: Double
    /// フィルムの帯と巻きつまみの見え方
    var film: Double
    /// 巻いた量(pt)。1こま = 242pt
    var advance: Double
    /// 巻きつまみの回転(度)
    var crankAngle: Double
    /// 撮ったこまの見え方
    var takenFrame: Double
    /// 撮った時刻のスタンプの見え方
    var stamp: Double
    /// 空のこまの「9:00」の見え方
    var nextOpening: Double
    /// 全体のフェード(動きをへらす時の、最後の絵への切りかえ)
    var fade: Double
}

/// 撮影が成立した瞬間を 0 秒とする時間割。数字は仕様(デモHTMLの drawDep と同じ)。
enum CaptureAfterShot {
    /// 1こまぶんの送り(pt)
    static let frameStep: Double = 242
    static let clickCount = 6
    /// 巻きつまみの1回のカチカチ(秒)。動くのは前半45%
    static let clickInterval: Double = 0.15
    static let clickStart: Double = 0.45
    /// 最後の絵で止まり、0.6秒おいて終わる(秒)
    static let total: TimeInterval = 2.25
    /// 動きをへらす時(秒):0.4秒でフェードして、0.6秒おく
    static let reducedTotal: TimeInterval = 1.0

    /// 撮ったあとの「次の撮影時刻」の文字(撮影の開始時刻から作る)
    static var nextOpeningText: String { "\(DailyExposureRules.openingHour):00" }

    static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? reducedTotal : total
    }

    static func frame(at t: Double, reduceMotion: Bool) -> CaptureAfterShotFrame {
        if reduceMotion {
            return CaptureAfterShotFrame(
                flash: flashLevel(t, peak: 0.4),
                chrome: 0,
                window: 0,
                film: 1,
                advance: frameStep,
                crankAngle: 0,
                takenFrame: 0,
                stamp: 0,
                nextOpening: 0.7,
                fade: smooth(t / 0.4)
            )
        }
        let clicks = clickProgress(at: t)
        return CaptureAfterShotFrame(
            flash: flashLevel(t, peak: 0.95),
            chrome: 1 - smooth(t / 0.18),
            window: 1 - smooth((t - 0.15) / 0.15),
            film: smooth((t - 0.22) / 0.23),
            advance: clicks * frameStep / Double(clickCount),
            crankAngle: clicks * 60,
            takenFrame: 1 - smooth((t - 1.4) / 0.25),
            stamp: smooth((t - 0.3) / 0.2),
            nextOpening: 0.7 * smooth((t - 1.4) / 0.25),
            fade: 1
        )
    }

    /// 巻いたカチカチの数(0〜6)。1回ぶんは前半45%だけ動き、残りは止まる。
    static func clickProgress(at t: Double) -> Double {
        var total = 0.0
        for index in 0..<clickCount {
            let start = clickStart + Double(index) * clickInterval
            guard t > start else { break }
            let fraction = min(1, (t - start) / clickInterval)
            total = Double(index) + smooth(min(fraction / 0.45, 1))
        }
        return total
    }

    /// 白いフラッシュ:0〜0.2秒で、peak から 0 へ。
    static func flashLevel(_ t: Double, peak: Double) -> Double {
        guard t < 0.2 else { return 0 }
        return peak * (1 - smooth(t / 0.2))
    }

    /// 0〜1 の間を、なめらかに変える(ease-in-out)。
    static func smooth(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return c * c * (3 - 2 * c)
    }
}

// MARK: - 描く部分

/// フィルムの帯・こま・巻きつまみ・撮った時刻・空のこまの「9:00」。
/// 位置は 390pt 幅の基準で、幅が違う端末では中央にそろえる。
struct CaptureFilmAdvanceLayer: View {
    let frame: CaptureAfterShotFrame
    /// 撮った時刻(撮ったこまのスタンプ)
    let exposedAt: Date?

    /// 帯の左右の位置(390pt 基準)
    private static let bandLeft: CGFloat = 93
    private static let bandWidth: CGFloat = 204
    private static let frameWidth: CGFloat = 170
    private static let frameHeight: CGFloat = 226
    private static let frameLeft: CGFloat = 110
    /// 1こま目の中心(巻く前)
    private static let firstFrameCenterY: CGFloat = 338
    private static let holePitch: CGFloat = 30.25
    private static let crankCenter = CGPoint(x: 322, y: 770)

    var body: some View {
        GeometryReader { proxy in
            let dx = (proxy.size.width - 390) / 2
            let advance = CGFloat(frame.advance)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    context.translateBy(x: dx, y: 0)
                    drawFilm(into: &context, height: size.height, advance: advance)
                }

                CaptureCrank(angle: frame.crankAngle)
                    .opacity(frame.film * frame.fade)
                    .offset(x: dx + Self.crankCenter.x - 26, y: Self.crankCenter.y - 26)

                if let exposedAt {
                    SevenSegmentText(text: Self.timeText(exposedAt), height: 16)
                        .padding(.trailing, 120)
                        .frame(width: 390, alignment: .trailing)
                        .opacity(frame.stamp * frame.takenFrame * frame.fade)
                        .offset(x: dx, y: Self.firstFrameCenterY - advance + 93)
                }

                Text(CaptureAfterShot.nextOpeningText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(CaptureRetro.accent)
                    .frame(width: 390)
                    .opacity(frame.nextOpening * frame.fade)
                    // 空のこま(2つ目)の中心に合わせる
                    .offset(x: dx, y: Self.firstFrameCenterY + CaptureAfterShot.frameStep - advance - 10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 帯・こま・穴を描く。こまの k=0 が撮ったこま、k≥1 は空のこま(点線)。
    private func drawFilm(into context: inout GraphicsContext, height: CGFloat, advance: CGFloat) {
        let filmOpacity = frame.film * frame.fade

        context.opacity = filmOpacity
        let band = CGRect(x: Self.bandLeft, y: 0, width: Self.bandWidth, height: height)
        context.fill(Path(band), with: .color(Color(red: 16 / 255, green: 16 / 255, blue: 22 / 255).opacity(0.96)))
        var edges = Path()
        edges.move(to: CGPoint(x: Self.bandLeft, y: 0))
        edges.addLine(to: CGPoint(x: Self.bandLeft, y: height))
        edges.move(to: CGPoint(x: Self.bandLeft + Self.bandWidth, y: 0))
        edges.addLine(to: CGPoint(x: Self.bandLeft + Self.bandWidth, y: height))
        context.stroke(edges, with: .color(.white.opacity(0.10)), lineWidth: 1)

        // 穴(左右2列)。巻いた分だけ上へ動く。
        let holeOffset = advance.truncatingRemainder(dividingBy: Self.holePitch)
        for holeLeft in [CGFloat(103), 279] {
            for index in -2...Int(height / Self.holePitch) + 2 {
                let y = CGFloat(index) * Self.holePitch - holeOffset
                let rect = CGRect(x: holeLeft, y: y, width: 8, height: 12)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(.white.opacity(0.30)))
            }
        }

        // こま:k=0 は撮ったこま(暗く、橙の縁)。k≥1 は空のこま(点線)。
        for index in 0...3 {
            let centerY = Self.firstFrameCenterY + CGFloat(index) * CaptureAfterShot.frameStep - advance
            let rect = CGRect(
                x: Self.frameLeft,
                y: centerY - Self.frameHeight / 2,
                width: Self.frameWidth,
                height: Self.frameHeight
            )
            let path = Path(roundedRect: rect, cornerRadius: 12)
            if index == 0 {
                context.opacity = filmOpacity * frame.takenFrame
                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: "17171f"), Color(hex: "08080c")]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    )
                )
                context.stroke(path, with: .color(Color(red: 1, green: 150 / 255, blue: 70 / 255).opacity(0.55)), lineWidth: 1.5)
            } else {
                context.opacity = filmOpacity
                context.fill(path, with: .color(.white.opacity(0.02)))
                context.stroke(
                    path,
                    with: .color(.white.opacity(0.24)),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 6])
                )
            }
        }
    }

    /// 撮った時刻「HH:MM:SS」
    private static func timeText(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

/// 巻きつまみ(直径52)。カチカチの回数ぶん、60°ずつまわる。
struct CaptureCrank: View {
    let angle: Double

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "121218"))
            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
            ForEach(0..<16, id: \.self) { index in
                let long = index % 2 == 0
                VStack(spacing: 0) {
                    Capsule()
                        .fill(.white.opacity(long ? 0.5 : 0.25))
                        .frame(width: 1.4, height: long ? 6 : 3)
                        .padding(.top, 3)
                    Spacer(minLength: 0)
                }
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(Double(index) * 22.5))
            }
            VStack(spacing: 0) {
                Circle()
                    .fill(CaptureRetro.orange)
                    .frame(width: 6, height: 6)
                    .padding(.top, 9)
                Spacer(minLength: 0)
            }
            .frame(width: 52, height: 52)
        }
        .frame(width: 52, height: 52)
        .rotationEffect(.degrees(angle))
    }
}
