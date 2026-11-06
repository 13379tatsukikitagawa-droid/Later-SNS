import SwiftUI
import UIKit

// v18.2:撮ったら、毎回ホームへもどる。撮った写真は一度も見せない。
// 撮影画面:ブリンク(0)→ フラッシュ(0.12)→ ミルク色のチェキに入れかえて縮む(0.23・ばね)→ 0.78 でホームへ引きつぐ
// ホーム:今日の film まで自動でスクロール(0.4秒)→ 1.08 から 0.6秒で物干しの空きこまへ弧を描いてとぶ → テープでとまって揺れる
// 保存と、この見せる処理はつなげない(保存は写真が返った時点で1回。動きは待たない)。

enum ShotTiming {
    static let blink: Double = 0
    static let flash: Double = 0.12
    static let toCheki: Double = 0.23
    static let pop: Double = 0.30
    static let handOff: Double = 0.78
    static let flyStart: Double = 1.08
    static let flyDuration: Double = 0.6
    /// 縮んだチェキ(200×250・-5°)
    static let chekiSize = CGSize(width: 200, height: 250)
    static let chekiTilt: Double = -5
}

/// 撮ったチェキの引きつぎ(撮影画面 → ホーム)
struct ShotHandOff: Equatable {
    let id = UUID()
    /// 画面の座標での、チェキの位置
    let rect: CGRect
    /// その日の何こめか(0 から)
    let index: Int
    let isVideo: Bool
    let duration: Double?
}

/// ホームの「今日の film」の物干しのこまの位置(画面の座標)と、着地の知らせ。区画とホームのあいだで共有する
@MainActor @Observable
final class FilmLanding {
    static let shared = FilmLanding()

    /// こまの番号 → 画面の座標の位置
    var slotFrames: [Int: CGRect] = [:]
    /// とんでいる最中・着いたあと、データが来るまで置いておく こま(まだ保存が終わっていなくても、ミルク色で出す)
    var pending: (index: Int, isVideo: Bool, duration: Double?)?
    /// 増えるたびに、今日の film までスクロールする
    var scrollToken = 0
    /// 着いた(そのこまを揺らす)
    var landedToken = 0
    var landedIndex: Int?

    nonisolated init() {}
}

/// ミルク色のチェキ(写真は見せない)。動画のときは左右にフィルムの穴と ▶ 長さ
struct MilkCheki: View {
    var isVideo = false
    var duration: Double?
    var stamp: String = HomeV17Rules.chekiDate(Date())

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let pad = w * 0.06
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: w * 0.02, style: .continuous).fill(Color(hex: "F7F4EE"))
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        if isVideo { sprockets(width: w * 0.045) }
                        V17Milk(density: 0)
                            .background(LinearGradient(colors: [Color(hex: "DDE6E2"), Color(hex: "C9D3E0")], startPoint: .top, endPoint: .bottom))
                        if isVideo { sprockets(width: w * 0.045) }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .frame(height: proxy.size.height * 0.74)
                    HStack {
                        if isVideo, let duration {
                            Text("▶ \(Self.durationText(duration))")
                                .font(.system(size: max(8, w * 0.06), weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "FF8A2A"))
                        }
                        Spacer(minLength: 0)
                        Text(stamp).font(.custom("Caveat-Bold", size: max(10, w * 0.09))).foregroundStyle(Color(hex: "FF7A1A"))
                    }
                    .padding(.top, pad * 0.6)
                    Spacer(minLength: 0)
                }
                .padding(pad)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isVideo ? "動画。あしたの朝 9:00 に ひらきます" : "写真。あしたの朝 9:00 に ひらきます")
    }

    private func sprockets(width: CGFloat) -> some View {
        GeometryReader { proxy in
            let hole = width * 0.55
            let count = max(3, Int(proxy.size.height / (hole * 1.9)))
            ZStack {
                Color(hex: "111111")
                VStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1).fill(Color(hex: "F7F4EE").opacity(0.85))
                            .frame(width: hole, height: hole * 0.9)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(width: width)
    }

    /// 「0:08」
    static func durationText(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}

/// 撮影画面の中:ブリンク → フラッシュ → ミルク色のチェキに入れかえて縮む
struct ShotSequenceOverlay: View {
    let start: Date
    let finder: CGRect
    let center: CGPoint
    let isVideo: Bool
    let duration: Double?
    let flashOn: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            ZStack {
                // ブリンク(0〜0.15 窓が黒く)
                if t < 0.15 {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.black)
                        .frame(width: finder.width, height: finder.height)
                        .position(x: finder.midX, y: finder.midY)
                }
                // 窓が白く光る(フラッシュ ON なら、画面全体)
                if t >= ShotTiming.flash && t < ShotTiming.flash + 0.22 {
                    let k = 1 - (t - ShotTiming.flash) / 0.22
                    if flashOn {
                        Color.white.opacity(0.9 * k).ignoresSafeArea()
                    } else {
                        RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.95 * k))
                            .frame(width: finder.width, height: finder.height)
                            .position(x: finder.midX, y: finder.midY)
                    }
                }
                // ミルク色のチェキ(写真は一度も見せない)
                if t >= ShotTiming.toCheki {
                    let k = reduceMotion ? 1 : Self.spring(min(1, (t - ShotTiming.toCheki) / 0.5))
                    let from = finder.size, to = ShotTiming.chekiSize
                    let size = CGSize(width: from.width + (to.width - from.width) * k, height: from.height + (to.height - from.height) * k)
                    let pos = CGPoint(x: finder.midX + (center.x - finder.midX) * k, y: finder.midY + (center.y - finder.midY) * k)
                    MilkCheki(isVideo: isVideo, duration: duration)
                        .frame(width: size.width, height: size.height)
                        .rotationEffect(.degrees(ShotTiming.chekiTilt * k))
                        .position(pos)
                        .opacity(reduceMotion ? min(1, (t - ShotTiming.toCheki) / 0.15) : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// 少し行きすぎて戻る、ばね
    static func spring(_ x: Double) -> Double {
        1 - exp(-6 * x) * cos(9 * x)
    }
}

/// ホームの上:引きついだチェキが、今日の film の空きこまへ とぶ
struct ShotFlightOverlay: View {
    let handOff: ShotHandOff
    let start: Date
    let reduceMotion: Bool
    let onLand: () -> Void

    @State private var landed = false

    var body: some View {
        let landing = FilmLanding.shared
        TimelineView(.animation(paused: landed)) { context in
            let t = context.date.timeIntervalSince(start) + ShotTiming.handOff
            let from = handOff.rect
            // 着く先:物干しのこま(わからなければ、上の方)
            let target = landing.slotFrames[handOff.index] ?? CGRect(x: from.midX - 49, y: 160, width: 98, height: 137)
            let tilt = HomeV17Rules.filmTilts[min(max(handOff.index, 0), 2)]
            let p = max(0, min(1, (t - ShotTiming.flyStart) / ShotTiming.flyDuration))
            let e = reduceMotion ? p : (p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2)
            // 弧:まん中の点を上にあげる
            let control = CGPoint(x: (from.midX + target.midX) / 2, y: min(from.midY, target.midY) - 160)
            let pos = Self.bezier(CGPoint(x: from.midX, y: from.midY), control, CGPoint(x: target.midX, y: target.midY), e)
            let w = from.width + (target.width - from.width) * e
            let h = from.height + (target.height - from.height) * e
            MilkCheki(isVideo: handOff.isVideo, duration: handOff.duration)
                .frame(width: w, height: h)
                .rotationEffect(.degrees(ShotTiming.chekiTilt + (tilt - ShotTiming.chekiTilt) * e))
                .position(pos)
                .opacity(reduceMotion && p > 0 ? 1 - p * 0.3 : 1)
                .onChange(of: p >= 1) { _, done in
                    if done && !landed {
                        landed = true
                        onLand()
                    }
                }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    static func bezier(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }
}
