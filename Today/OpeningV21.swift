import SwiftUI

// オープニング(v72 B)の 設定。画面は `V64/OpeningV72View.swift`。
// アプリを 起動した とき だけ(戻った ときは 出さない)。設定で オン / 短く / オフ。視差を 減らす:最後の 組みを 0.6秒 → フェード。

enum OpeningMode: String, CaseIterable, Identifiable {
    case on, short, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .on: return "オン"
        case .short: return "短く"
        case .off: return "オフ"
        }
    }
}

enum OpeningSettings {
    private static let modeKey = "opening.mode"

    static var mode: OpeningMode {
        get { UserDefaults.standard.string(forKey: modeKey).flatMap(OpeningMode.init(rawValue:)) ?? .on }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modeKey) }
    }

    /// 今回の起動で流すもの(nil = 流さない)
    static func variant(reduceMotion: Bool) -> OpeningVariant? {
        switch mode {
        case .off: return nil
        case _ where reduceMotion: return .fade
        case .short: return .short
        case .on: return .full
        }
    }
}

/// full = アイコンが 横へ → Lattag + 9:00 → ひらく(2.48秒)/ short = 0.33秒 → すぐ ひらく(通知 ・ 設定「短く」)/ fade = 動かさない 版
enum OpeningVariant: Equatable {
    case full, short, fade

    /// 全体の 長さ(秒)
    var duration: Double {
        switch self {
        case .full: return 2.48
        case .short: return 1.45
        case .fade: return 1.0
        }
    }
}

extension Notification.Name {
    /// オープニングが終わった(Home の登場を流す)
    static let openingFinished = Notification.Name("openingFinished")
}

enum OpeningStyle {
    /// モックの `p2`:「11.06」(出だしの 点つき「'26 11 06」)
    static func shortDate(_ d: Date, apostrophe: Bool = false) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        let yy = (c.year ?? 2026) % 100
        return apostrophe ? String(format: "'%02d %02d %02d", yy, c.month ?? 1, c.day ?? 1) : String(format: "%02d.%02d", c.month ?? 1, c.day ?? 1)
    }
}

enum OpeningEase {
    /// CSS の `cubic-bezier(a,b,c,d)`(x → 進み具合)
    static func bezier(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double) -> Double {
        let x = min(1, max(0, x))
        if x == 0 || x == 1 { return x }
        func bx(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * c + t * t * t }
        func by(_ t: Double) -> Double { 3 * (1 - t) * (1 - t) * t * b + 3 * (1 - t) * t * t * d + t * t * t }
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 { let m = (lo + hi) / 2; if bx(m) < x { lo = m } else { hi = m } }
        return by((lo + hi) / 2)
    }
    static func out(_ x: Double) -> Double { 1 - pow(1 - min(1, max(0, x)), 3) }
    static func inOut(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
    static func lerp(_ a: CGRect, _ b: CGRect, _ t: Double) -> CGRect {
        let k = CGFloat(t)
        return CGRect(x: a.minX + (b.minX - a.minX) * k, y: a.minY + (b.minY - a.minY) * k,
                      width: a.width + (b.width - a.width) * k, height: a.height + (b.height - a.height) * k)
    }
}
