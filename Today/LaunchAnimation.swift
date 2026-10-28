import SwiftUI
import UIKit

// MARK: - 起動の種類

/// 起動アニメーション(案2:あなたの光から、ひろがる)。経過時間 t(ms)から、すべての要素の見た目を
/// 計算する純粋な関数(LaunchFrame.at)として作り、1本の時計 t で全体を動かす。
enum LaunchKind: String, CaseIterable, Sendable {
    /// その窓(9:00〜翌9:00)の最初のコールドスタート
    case morning
    case normal
    /// 夜(00:00〜9:00)
    case night
}

/// 起動の種類を選ぶ・その窓で morning を出したかを覚える。
@MainActor
enum LaunchCoordinator {
    static let lastMorningWindowKey = "lastMorningWindowKey"

    /// このプロセスで、すでに起動アニメーションを出したか(コールドスタートの判定)
    static var hasPlayedInProcess = false
    /// 通知から起動した(SceneDelegateが立てる)
    static var launchedFromNotification = false

    /// - Parameters:
    ///   - now: 現在時刻(時計は注入できる)
    ///   - lastMorningKey: 最後に morning を出した窓のキー
    static func kind(now: Date, lastMorningKey: String?, fromNotification: Bool, calendar: Calendar = .current) -> LaunchKind {
        if DailyWindow.isNight(now, calendar: calendar) { return .night }
        if fromNotification { return .normal }
        return lastMorningKey == DailyWindow.key(for: now, calendar: calendar) ? .normal : .morning
    }

    /// コールドスタートの最初の1回だけ種類を返す(2回目以降・ウォーム起動はnil)。
    /// morning を選んだら、起動の開始時に「この窓では出した」と保存する。
    static func beginColdLaunchIfNeeded(now: Date, defaults: UserDefaults = .standard) -> LaunchKind? {
        guard !hasPlayedInProcess else { return nil }
        hasPlayedInProcess = true
        let kind = kind(now: now, lastMorningKey: defaults.string(forKey: lastMorningWindowKey), fromNotification: launchedFromNotification)
        if kind == .morning {
            defaults.set(DailyWindow.key(for: now), forKey: lastMorningWindowKey)
        }
        return kind
    }
}

// MARK: - 時間割(ms)

/// 案2「あなたの光から、ひろがる」の時間割。
/// 球(ガラス)→ あなたの光 → 波紋と、世界の光のひろがり → 数字 → 文字・カード → 月
struct LaunchSpec: Sendable {
    typealias Span = (Double, Double)

    let total: Double
    /// 光の球のガラス
    let glass: Span
    /// あなたの光がともる
    let youIn: Span
    /// あなたの光の波紋(sweep と同時に始まる)
    let pulse: Span
    /// 世界の光のひろがり(数字もここで0から増える)
    let sweep: Span
    let bg: Span
    let moon: Span
    /// 月がのぼる距離(pt)
    let travel: CGFloat
    /// 月のにじみの拡大(0ならにじみを出さない)
    let glow: Double
    let hdr: Span
    let head: Span
    let card: Span
    let grp: Span

    /// 触れるようになる時刻(sweep が終わるとき。それまでのタップはスキップ)
    var interactiveAt: Double { sweep.1 }

    static func of(_ kind: LaunchKind) -> LaunchSpec {
        switch kind {
        case .morning:
            return LaunchSpec(total: 3000, glass: (200, 700), youIn: (500, 1000), pulse: (1050, 1700), sweep: (1050, 2150), bg: (100, 1700),
                              moon: (100, 1500), travel: 340, glow: 0.9,
                              hdr: (2100, 2550), head: (2200, 2650), card: (2350, 2800), grp: (2450, 2900))
        case .normal:
            return LaunchSpec(total: 1700, glass: (40, 360), youIn: (120, 480), pulse: (450, 900), sweep: (450, 1100), bg: (200, 900),
                              moon: (900, 1550), travel: 130, glow: 0.3,
                              hdr: (800, 1150), head: (850, 1200), card: (950, 1300), grp: (1050, 1400))
        case .night:
            return LaunchSpec(total: 2200, glass: (100, 600), youIn: (400, 900), pulse: (900, 1500), sweep: (900, 1700), bg: (300, 1500),
                              moon: (1200, 2000), travel: 90, glow: 0,
                              hdr: (1200, 1700), head: (1300, 1800), card: (1450, 1950), grp: (1550, 2050))
        }
    }

    /// デバッグ・書き出し用に止める時刻
    static func debugTimes(_ kind: LaunchKind) -> [Double] {
        switch kind {
        case .morning: return [0, 500, 900, 1200, 1600, 2000, 2500, 3000]
        case .normal: return [0, 200, 500, 700, 1000, 1400, 1700]
        case .night: return [0, 500, 900, 1300, 1700, 2000, 2200]
        }
    }
}

// MARK: - 曲線

enum LaunchCurve {
    static func seg(_ t: Double, _ span: LaunchSpec.Span) -> Double {
        guard span.1 > span.0 else { return t >= span.1 ? 1 : 0 }
        return min(1, max(0, (t - span.0) / (span.1 - span.0)))
    }

    /// ぬるっと止まる(ほぼ全部これ)
    static func e1(_ x: Double) -> Double { bezier(x, 0.2, 0.8, 0.2, 1) }
    /// 背景・数字用
    static func e2(_ x: Double) -> Double { bezier(x, 0.4, 0, 0.2, 1) }

    /// cubic-bezier(x1, y1, x2, y2) の、xに対するy(ニュートン法+二分法)
    static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        func sample(_ t: Double, _ a1: Double, _ a2: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a1 + 3 * u * t * t * a2 + t * t * t
        }
        func slope(_ t: Double, _ a1: Double, _ a2: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * a1 + 6 * u * t * (a2 - a1) + 3 * t * t * (1 - a2)
        }
        var t = x
        for _ in 0..<8 {
            let dx = sample(t, x1, x2) - x
            let d = slope(t, x1, x2)
            if abs(dx) < 1e-6 { return sample(t, y1, y2) }
            if abs(d) < 1e-6 { break }
            t -= dx / d
        }
        var lo = 0.0, hi = 1.0
        t = x
        for _ in 0..<30 {
            let v = sample(t, x1, x2)
            if abs(v - x) < 1e-6 { break }
            if v < x { lo = t } else { hi = t }
            t = (lo + hi) / 2
        }
        return sample(t, y1, y2)
    }
}

// MARK: - ある時刻の見た目

/// 経過時間 t(ms)での、すべての要素の見た目。LaunchFrame.finished は「アニメーションなし」と同じ。
struct LaunchFrame: Equatable, Sendable {
    /// 光の球のガラス
    var glassScale: Double = 1
    var glassOpacity: Double = 1
    /// 球のにじみ
    var haloOpacity: Double = 1
    /// あなたの光(輪も点も)
    var youOpacity: Double = 1
    /// あなたの光の波紋の進み(0 < pulse < 1 のあいだだけ描く)
    var pulse: Double = 0
    /// 世界の光のひろがりの進み p(点ごとの灯り具合は LaunchFrame.reveal で求める)
    var sweep: Double = 1
    /// 背景の光
    var bgOpacity: Double = 1
    /// 数字(0から増える割合と、不透明度)
    var countFraction: Double = 1
    var countOpacity: Double = 1
    var headerOpacity: Double = 1
    var headOpacity: Double = 1
    var headOffset: CGFloat = 0
    var cardOpacity: Double = 1
    var cardOffset: CGFloat = 0
    var groupOpacity: Double = 1
    var groupOffset: CGFloat = 0
    var moonOpacity: Double = 1
    var moonOffset: CGFloat = 0
    /// 月のにじみ(nilなら通常どおり)
    var moonGlowOpacity: Double? = nil
    var moonGlowScale: Double = 1

    static let finished = LaunchFrame()

    static func at(_ t: Double, kind: LaunchKind) -> LaunchFrame {
        let s = LaunchSpec.of(kind)
        if t >= s.total { return .finished }
        typealias C = LaunchCurve
        var f = LaunchFrame()

        let glass = C.seg(t, s.glass)
        let sg = C.e1(glass)
        f.glassScale = 0.9 + 0.1 * sg
        f.glassOpacity = min(1, 3 * glass)
        f.haloOpacity = sg
        f.youOpacity = C.e1(C.seg(t, s.youIn))
        f.pulse = C.seg(t, s.pulse)

        let p = C.e2(C.seg(t, s.sweep))
        f.sweep = p
        f.countFraction = p
        f.countOpacity = min(1, 3 * p)

        f.bgOpacity = C.e2(C.seg(t, s.bg))
        f.headerOpacity = C.seg(t, s.hdr)
        let head = C.seg(t, s.head)
        f.headOpacity = head
        f.headOffset = 12 * CGFloat(1 - C.e1(head))
        let card = C.seg(t, s.card)
        f.cardOpacity = card
        f.cardOffset = 16 * CGFloat(1 - C.e1(card))
        let grp = C.seg(t, s.grp)
        f.groupOpacity = grp
        f.groupOffset = 16 * CGFloat(1 - C.e1(grp))

        let moon = C.seg(t, s.moon)
        f.moonOpacity = min(1, 2.5 * moon)
        f.moonOffset = s.travel * CGFloat(1 - C.e1(moon))
        f.moonGlowOpacity = 0.7 * moon * (s.glow > 0 ? 1 : 0)
        f.moonGlowScale = 1 + s.glow * (1 - C.e1(moon))
        return f
    }

    /// 点 i の「灯り具合」rv。d = 点とあなたの光の距離 ÷ 球の直径(0〜約1)。
    /// あなたの光に近い点から、波のように灯る(先端は 0.3 の幅でやわらかく立ち上がる)。
    static func reveal(sweep p: Double, distance d: Double) -> Double {
        min(1, max(0, (p * 1.35 - d) / 0.3))
    }

    /// 灯る瞬間に少しふくらんで、おちつく(ぽっ、と灯る)。rv = 1 で 1 倍
    static func revealScale(_ rv: Double) -> Double {
        0.55 + 0.45 * rv + 0.315 * sin(.pi * min(1, rv))
    }

    static func revealOpacity(_ rv: Double) -> Double {
        min(1, rv * 1.4)
    }
}

// MARK: - 時計

/// 起動アニメーションの1本の時計。スキップ(200msで最後へ)・低電力モード(2倍速)を扱う。
struct LaunchClock: Equatable {
    let kind: LaunchKind
    let start: Date
    /// 低電力モードでは2(t の進みを2倍にする)
    let speed: Double
    /// スキップした時刻と、その時点の t
    var skip: (at: Date, from: Double)?
    /// デバッグ:この t で止めて表示する(タップで最後へ)
    var frozenT: Double?

    static let skipDuration: TimeInterval = 0.2

    var spec: LaunchSpec { .of(kind) }

    func t(at date: Date) -> Double {
        let raw = frozenT ?? max(0, date.timeIntervalSince(start)) * 1000 * speed
        guard let skip else { return raw }
        let u = min(1, max(0, date.timeIntervalSince(skip.at) / Self.skipDuration))
        return skip.from + (spec.total - skip.from) * u
    }

    func isFinished(at date: Date) -> Bool { t(at: date) >= spec.total }

    /// 終わるまでの実時間(秒)
    func remaining(at date: Date) -> TimeInterval {
        if let skip { return max(0, Self.skipDuration - date.timeIntervalSince(skip.at)) }
        if frozenT != nil { return .infinity }
        return max(0, (spec.total - t(at: date)) / 1000 / speed)
    }

    static func == (a: LaunchClock, b: LaunchClock) -> Bool {
        a.kind == b.kind && a.start == b.start && a.speed == b.speed && a.skip?.at == b.skip?.at && a.frozenT == b.frozenT
    }
}

// MARK: - デバッグ(設定メニューから再生・時刻を指定して止める)

extension Notification.Name {
    /// userInfo: "kind"(LaunchKind.rawValue)、"speed"(Double)、"frozenT"(Double・任意)
    static let replayLaunchAnimation = Notification.Name("replayLaunchAnimation")
}
