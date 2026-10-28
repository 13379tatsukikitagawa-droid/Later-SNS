import SwiftUI
import WidgetKit

/// 1つの時刻の見た目。状態は時刻と共有の値だけで決まる(derive)
struct LaterEntry: TimelineEntry {
    let date: Date
    let state: LaterWidgetState
}

/// 15分ごとの Entry を、次の 9:00 まで先に作る。Policy は次の 9:00。
/// 撮影・昨日をひらく操作の反映は、アプリからの reload で行う。
struct LaterProvider: TimelineProvider {
    static let step: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> LaterEntry {
        let now = Date()
        return LaterEntry(date: now, state: .derive(.empty, now: now))
    }

    func getSnapshot(in context: Context, completion: @escaping (LaterEntry) -> Void) {
        let now = Date()
        completion(LaterEntry(date: now, state: .derive(LaterWidgetSnapshot.load(), now: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LaterEntry>) -> Void) {
        let now = Date()
        let snapshot = LaterWidgetSnapshot.load()
        let end = LaterWidgetDay.nextOpening(after: now)
        var dates: [Date] = [now]
        var t = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / Self.step).rounded(.up) * Self.step)
        while t < end {
            dates.append(t)
            t = t.addingTimeInterval(Self.step)
        }
        // 消灯(24:00)ちょうどにも、1つ置く(U → M)
        let lightsOut = LaterWidgetDay.lightsOut(of: now)
        if lightsOut > now { dates.append(lightsOut) }
        let entries = Set(dates).sorted().map { LaterEntry(date: $0, state: .derive(snapshot, now: $0)) }
        completion(Timeline(entries: entries, policy: .after(end)))
    }
}

// MARK: - 文言(事実だけ。ほめない、せかさない)

enum LaterWidgetCopy {
    static func title(_ phase: LaterWidgetPhase, short: Bool = false) -> String {
        switch phase {
        case .U: return "今日を撮る"
        case .R: return short ? "昨日をひらく" : "昨日が、ひらけます"
        case .D: return "現像中"
        case .M: return "消灯しました"
        }
    }

    static func sub(_ state: LaterWidgetState) -> String {
        switch state.phase {
        case .U: return "消灯まで"
        case .R: return "今日の1枚 現像 \(state.developPercent)%"
        case .D: return "あしたの朝 9:00"
        case .M: return "あしたの朝 09:00"
        }
    }
}

// MARK: - 色

enum LaterWidgetPalette {
    static let skyTop = Color(red: 5 / 255, green: 3 / 255, blue: 11 / 255)
    static let skyHorizon = Color(red: 38 / 255, green: 18 / 255, blue: 62 / 255)
    static let orange = Color(red: 1, green: 178 / 255, blue: 110 / 255)
    static let litDot = Color(red: 1, green: 214 / 255, blue: 170 / 255)

    /// 月の色:9:00 のクリーム → 夕方のもも色 → 夜のピンク(連続)
    static func moon(_ progress: Double) -> Color {
        let cream = (1.0, 0.95, 0.84), peach = (1.0, 0.78, 0.66), pink = (1.0, 0.62, 0.75)
        let (a, b, t) = progress < 0.6 ? (cream, peach, progress / 0.6) : (peach, pink, (progress - 0.6) / 0.4)
        return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }

    /// 天体の色(月 or 円盤)。地平線の光・地面のふちにうつる
    static func celestial(_ state: LaterWidgetState) -> Color {
        switch state.phase {
        case .U: return moon(state.dayProgress)
        case .R, .D: return orange
        case .M: return Color(red: 0.55, green: 0.5, blue: 0.85)
        }
    }
}

/// 固定の乱数(毎回同じ位置)
struct LaterSeeded {
    static func value(_ i: Int, _ salt: Double) -> Double {
        let x = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }
}
