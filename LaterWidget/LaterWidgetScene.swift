import SwiftUI
import WidgetKit

// 景色:空 → 星 → 地平線の光 → 天体(月 or 円盤) → 地面 → 昨日の円盤 → 文字 → 点(7日) → 粒子(grain)

struct LaterSceneView: View {
    let state: LaterWidgetState
    let family: WidgetFamily

    @Environment(\.widgetRenderingMode) private var renderingMode
    private var accented: Bool { renderingMode != .fullColor }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = SceneLayout(size: size, family: family, state: state)
            ZStack(alignment: .topLeading) {
                LaterSky(state: state, horizonY: layout.horizonY, accented: accented)
                LaterStars(state: state, size: size, horizonY: layout.horizonY, accented: accented)
                celestial(layout: layout)
                LaterGround(state: state, size: size, horizonY: layout.horizonY, accented: accented)
                if state.hasYesterday || state.phase == .R {
                    yesterdayDisc(layout: layout)
                }
                texts(layout: layout)
                if family != .systemSmall {
                    LaterWeekConstellation(week: state.week, accented: accented)
                        .frame(width: layout.weekFrame.width, height: layout.weekFrame.height)
                        .position(x: layout.weekFrame.midX, y: layout.weekFrame.midY)
                    if family == .systemMedium {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("預けた日々")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .widgetAccentable()
                            Spacer(minLength: 0)
                            Text("写真は 7 日で消えます")
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .frame(width: layout.weekFrame.width, height: size.height - 28, alignment: .leading)
                        .position(x: layout.weekFrame.midX, y: size.height / 2)
                    }
                }
                if !accented {
                    LaterGrain(size: size).blendMode(.overlay).opacity(0.16).allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: 天体

    @ViewBuilder
    private func celestial(layout: SceneLayout) -> some View {
        switch state.phase {
        case .U:
            LaterMoon(progress: state.dayProgress, diameter: layout.moonDiameter, accented: accented)
                .position(layout.moonCenter)
        case .R, .D:
            LaterDevelopDisc(progress: state.developProgress, diameter: layout.discDiameter, accented: accented)
                .position(layout.discCenter)
        case .M:
            EmptyView()
        }
    }

    /// 昨日の円盤:地平線の上で、封(点線の輪)をされて待つ。R で封が実線のオレンジに
    private func yesterdayDisc(layout: SceneLayout) -> some View {
        let open = state.phase == .R
        let d = layout.yesterdayDiameter
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.22), Color(white: 0.06)], center: .topLeading, startRadius: 0, endRadius: d))
                    .frame(width: d, height: d)
                Circle()
                    .strokeBorder(open ? LaterWidgetPalette.orange : .white.opacity(0.55),
                                  style: StrokeStyle(lineWidth: open ? 1.5 : 1, dash: open ? [] : [2, 2.5]))
                    .frame(width: d + 8, height: d + 8)
                    .shadow(color: open && !accented ? LaterWidgetPalette.orange.opacity(0.8) : .clear, radius: 5)
                    .widgetAccentable()
            }
            if family == .systemLarge {
                Text(open ? "昨日が、ひらけます" : "昨日・封をされています")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize()
            }
        }
        .position(layout.yesterdayCenter)
    }

    // MARK: 文字

    /// タイトルは左上。大きな数字(時刻・%)は左下の地面(黒い部分)の上に置く(空や月に重ねない)。
    /// 大は左上に大きく(50pt)。細い字は使わない:数字は semibold・丸ゴシック、ラベルは medium 以上
    @ViewBuilder
    private func texts(layout: SceneLayout) -> some View {
        let large = family == .systemLarge
        let labelSize: CGFloat = large ? 12 : 10
        VStack(alignment: .leading, spacing: 3) {
            Text(LaterWidgetCopy.title(state.phase))
                .font(.system(size: large ? 22 : 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .widgetAccentable()
            if large {
                LaterBigNumber(state: state, size: 50, percentSize: 22)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            if !large {
                LaterBigNumber(state: state, size: 28, percentSize: 15)
            }
            Text(LaterWidgetCopy.sub(state))
                .font(.system(size: labelSize, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .widgetAccentable()
        }
        .padding(14)
        .frame(width: layout.textWidth, height: layout.size.height, alignment: .topLeading)
    }
}

/// 大きな数字:U は消灯までの残り時間(自動更新)、R・D は現像の%、M は 09:00。
/// semibold・丸ゴシック・等幅の数字。「%」は数字の約55%・不透明度0.88。
/// ティントでは白いまま保つ(widgetAccentable にしない)。うしろに、ごく薄い影
struct LaterBigNumber: View {
    let state: LaterWidgetState
    let size: CGFloat
    let percentSize: CGFloat

    var body: some View {
        Group {
            switch state.phase {
            case .U:
                Text(timerInterval: state.now...state.lightsOut, countsDown: true, showsHours: true)
                    .font(.system(size: size, weight: .semibold, design: .rounded))
            case .R, .D:
                Text("\(Text("\(state.developPercent)").font(.system(size: size, weight: .semibold, design: .rounded)))\(Text("%").font(.system(size: percentSize, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.88)))")
            case .M:
                Text("09:00")
                    .font(.system(size: size, weight: .semibold, design: .rounded))
            }
        }
        .monospacedDigit()
        .tracking(-0.03 * size)
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .shadow(color: .black.opacity(0.35), radius: 6)
    }
}

// MARK: - 位置

struct SceneLayout {
    let size: CGSize
    let family: WidgetFamily
    let state: LaterWidgetState

    /// 景色の幅(中は左半分、大・小は全体)
    var sceneWidth: CGFloat { family == .systemMedium ? size.width * 0.52 : size.width }
    var horizonY: CGFloat { size.height * (family == .systemLarge ? 0.72 : 0.6) }
    var textWidth: CGFloat { sceneWidth }

    var moonDiameter: CGFloat {
        switch family {
        case .systemLarge: return 112
        case .systemMedium: return 46
        default: return 42
        }
    }

    /// 月:9:00 は高く、24:00 で地平線の下へ沈む
    var moonCenter: CGPoint {
        let p = state.dayProgress
        let high = size.height * (family == .systemLarge ? 0.36 : 0.3)
        let low = horizonY + moonDiameter * 0.55
        return CGPoint(x: sceneWidth * 0.72, y: high + (low - high) * p)
    }

    var discDiameter: CGFloat { family == .systemLarge ? 104 : 46 }
    var discCenter: CGPoint { CGPoint(x: sceneWidth * 0.7, y: size.height * (family == .systemLarge ? 0.42 : 0.4)) }

    var yesterdayDiameter: CGFloat { family == .systemLarge ? 26 : 14 }
    var yesterdayCenter: CGPoint {
        // 小・中は、左下の大きな数字にかからないよう、地平線の右寄りに置く
        CGPoint(x: sceneWidth * (family == .systemLarge ? 0.2 : 0.9), y: horizonY - yesterdayDiameter * 0.6 - (family == .systemLarge ? 14 : 4))
    }

    /// 7日の星座:中は右半分、大は地面の上に横に
    var weekFrame: CGRect {
        switch family {
        case .systemMedium:
            return CGRect(x: size.width * 0.56, y: 30, width: size.width * 0.4, height: size.height - 64)
        default:
            return CGRect(x: 18, y: horizonY + 14, width: size.width - 36, height: size.height - horizonY - 28)
        }
    }
}

// MARK: - 部品

struct LaterSky: View {
    let state: LaterWidgetState
    let horizonY: CGFloat
    let accented: Bool

    var body: some View {
        // 天体が地平線に近いほど、その色が空にうつる(near)
        let near: Double = {
            switch state.phase {
            case .U: return state.dayProgress
            case .R, .D: return 0.35
            case .M: return 0.1
            }
        }()
        let glow = LaterWidgetPalette.celestial(state)
        ZStack {
            LinearGradient(colors: [LaterWidgetPalette.skyTop, LaterWidgetPalette.skyHorizon], startPoint: .top, endPoint: .bottom)
            if !accented {
                RadialGradient(colors: [glow.opacity(0.45 * near), .clear], center: UnitPoint(x: 0.65, y: 0.9), startRadius: 0, endRadius: 180)
            }
        }
    }
}

/// 星:時刻が遅いほど多く・明るく。位置は固定の乱数
struct LaterStars: View {
    let state: LaterWidgetState
    let size: CGSize
    let horizonY: CGFloat
    let accented: Bool

    var body: some View {
        let late: Double = {
            switch state.phase {
            case .U: return state.dayProgress
            case .M: return 1
            case .R, .D: return 0.7
            }
        }()
        let count = Int(10 + 30 * late)
        Canvas { context, _ in
            for i in 0..<count {
                let x = LaterSeeded.value(i, 1) * size.width
                let y = LaterSeeded.value(i, 2) * (horizonY - 10)
                let r = 0.4 + 0.9 * LaterSeeded.value(i, 3)
                let alpha = (0.25 + 0.6 * LaterSeeded.value(i, 4)) * (0.4 + 0.6 * late)
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 地面:ゆるく曲がった黒い楕円。上のふちに、天体の色の細い光(rim light)
struct LaterGround: View {
    let state: LaterWidgetState
    let size: CGSize
    let horizonY: CGFloat
    let accented: Bool

    var body: some View {
        let width = size.width * 1.8
        let height = (size.height - horizonY) * 2.6
        let rim = LaterWidgetPalette.celestial(state)
        Ellipse()
            .fill(Color.black)
            .overlay(Ellipse().stroke(rim.opacity(accented ? 0.5 : 0.75), lineWidth: 1).blur(radius: accented ? 0 : 0.6))
            .shadow(color: accented ? .clear : rim.opacity(0.5), radius: 6, y: -2)
            .frame(width: width, height: height)
            .position(x: size.width / 2, y: horizonY + height / 2)
    }
}

/// 月:円。色は 9:00 のクリーム → 夕方のもも色 → 夜のピンク
struct LaterMoon: View {
    let progress: Double
    let diameter: CGFloat
    let accented: Bool

    var body: some View {
        let color = LaterWidgetPalette.moon(progress)
        Circle()
            .fill(RadialGradient(colors: [.white, color], center: UnitPoint(x: 0.38, y: 0.32), startRadius: 0, endRadius: diameter * 0.7))
            .frame(width: diameter, height: diameter)
            .shadow(color: accented ? .clear : color.opacity(0.7), radius: diameter * 0.35)
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}

/// 円盤(写真のたま):黒い円 + 3色のにじみ + 渦 + ふちの光 + ハイライト。濃さ p で彩度・明るさ・不透明度。
/// まわりに点30個の輪(灯った点は淡いオレンジで光る)
struct LaterDevelopDisc: View {
    let progress: Double
    let diameter: CGFloat
    let accented: Bool

    var body: some View {
        let p = progress
        ZStack {
            Circle().fill(Color.black)
            if !accented {
                Circle().fill(Color(red: 1, green: 0.55, blue: 0.3)).frame(width: diameter * 0.6).offset(x: -diameter * 0.14, y: -diameter * 0.1).blur(radius: diameter * 0.16)
                Circle().fill(Color(red: 0.95, green: 0.4, blue: 0.6)).frame(width: diameter * 0.5).offset(x: diameter * 0.16, y: diameter * 0.08).blur(radius: diameter * 0.16)
                Circle().fill(Color(red: 0.45, green: 0.35, blue: 0.9)).frame(width: diameter * 0.5).offset(x: 0, y: diameter * 0.2).blur(radius: diameter * 0.18)
                Circle().fill(AngularGradient(colors: [.white.opacity(0.0), .white.opacity(0.18), .white.opacity(0.0)], center: .center))
            } else {
                Circle().fill(.white.opacity(0.25 + 0.6 * p))
            }
            Circle().strokeBorder(LaterWidgetPalette.orange.opacity(0.35 + 0.5 * p), lineWidth: 1)
            Circle().fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: diameter * 0.3))
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .saturation(0.3 + 0.7 * p)
        .brightness(-0.25 * (1 - p))
        .opacity(0.35 + 0.65 * p)
        .overlay {
            LaterDotRing(count: 30, lit: Int((Double(30) * p).rounded(.down)), diameter: diameter + 16, dot: 2.2, litColor: LaterWidgetPalette.litDot)
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// 点の輪(灯った点は明るく、灯っていない点はうすく)
struct LaterDotRing: View {
    let count: Int
    let lit: Int
    let diameter: CGFloat
    let dot: CGFloat
    var litColor: Color = .white
    var dimOpacity: Double = 0.28
    var startsAtTop = true

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = diameter / 2 - dot
            for i in 0..<count {
                let angle = -Double.pi / 2 + 2 * .pi * Double(i) / Double(count)
                let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                let rect = CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)
                let isLit = i < lit
                context.fill(Path(ellipseIn: rect), with: .color(isLit ? litColor : .white.opacity(dimOpacity)))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

/// 7日の星座:撮った日だけ点が灯り、灯った点を点線で結ぶ。撮らなかった日は点なし(位置だけ)
struct LaterWeekConstellation: View {
    let week: [Bool]
    let accented: Bool

    var body: some View {
        Canvas { context, size in
            let points: [CGPoint] = (0..<7).map { i in
                let x = size.width * (0.06 + 0.88 * Double(i) / 6)
                let y = size.height * (0.3 + 0.4 * LaterSeeded.value(i, 9))
                return CGPoint(x: x, y: y)
            }
            let lit = points.enumerated().filter { week.indices.contains($0.offset) && week[$0.offset] }.map(\.element)
            if lit.count > 1 {
                var path = Path()
                path.addLines(lit)
                context.stroke(path, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
            }
            for (i, point) in points.enumerated() {
                let isToday = i == 6
                if week.indices.contains(i), week[i] {
                    let r: CGFloat = isToday ? 3.2 : 2.4
                    if !accented {
                        context.fill(Path(ellipseIn: CGRect(x: point.x - r * 2.4, y: point.y - r * 2.4, width: r * 4.8, height: r * 4.8)), with: .color(LaterWidgetPalette.litDot.opacity(0.18)))
                    }
                    context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), with: .color(.white))
                } else if isToday {
                    // 今日はまだ:うすい輪だけ
                    context.stroke(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(.white.opacity(0.4)), lineWidth: 0.8)
                }
            }
        }
        .widgetAccentable()
        .accessibilityElement()
        .accessibilityLabel("この7日で、\(week.filter { $0 }.count)日撮りました")
    }
}

/// 粒子(grain):固定の乱数の小さな点(画像アセットのかわりに描く)
struct LaterGrain: View {
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            let count = Int(size.width * size.height / 60)
            for i in 0..<count {
                let x = LaterSeeded.value(i, 21) * size.width
                let y = LaterSeeded.value(i, 22) * size.height
                let v = LaterSeeded.value(i, 23)
                context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(v > 0.5 ? .white : .black))
            }
        }
    }
}
