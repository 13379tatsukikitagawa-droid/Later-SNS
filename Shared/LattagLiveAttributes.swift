import Foundation
#if canImport(ActivityKit)
import ActivityKit
import AppIntents

// P40(v97):ライブ アクティビティ = フィルム(夜)→ ラストコール → 朝の 部。PROMPT_v97.md。
// 秒は `Text(timerInterval:)` が 自動で 動かす(アプリから 毎秒 送らない)。画像は ActivityKit の 中身(4KB)に 入れず、
// App Group の ぼかし 画像の ファイル名 だけ 入れる。友だちの 本物の 写真は 出さない。

struct LattagLiveAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable { case film, lastCall, done, opening, opened }

    struct ContentState: Codable, Hashable {
        var phase: Phase
        /// 今日 撮った こま(0...3)
        var shotsTaken: Int
        /// 24:00(夜)か 9:00(朝)
        var endsAt: Date
        /// 撮った こまの ぼかし(App Group の w/<name>)
        var frameThumbs: [String]
        /// 朝の 部:きのう 撮った 友だちの 数
        var friendCount: Int
        /// 現像の 進み(%)
        var devPercent: Int
    }

    /// "2026-11-18"
    var dayKey: String
}

/// 「撮る」ボタン(島 ・ ラストコール)。アプリを ひらいて 撮影へ
struct OpenCameraIntent: AppIntent {
    static var title: LocalizedStringResource = "撮る"
    static var description = IntentDescription("Lattag を ひらいて 撮影へ")
    static var openAppWhenRun: Bool = true

    static let flagKey = "live.openCamera"

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: LattagShared.appGroup)?.set(Date().timeIntervalSince1970, forKey: Self.flagKey)
        return .result()
    }
}

enum LattagLiveClock {
    /// 夜の 始まり(23:00)・ ラストコール(23:50)・ 消灯(24:00)・ 朝の 部(8:30)・ ひらく(9:00)
    static func nightStart(_ now: Date, calendar: Calendar = .current) -> Date { at(23, 0, now, calendar) }
    static func lastCall(_ now: Date, calendar: Calendar = .current) -> Date { at(23, 50, now, calendar) }
    static func lightsOut(_ now: Date, calendar: Calendar = .current) -> Date { at(24, 0, now, calendar) }
    static func morningStart(_ now: Date, calendar: Calendar = .current) -> Date { at(8, 30, now, calendar) }
    static func opens(_ now: Date, calendar: Calendar = .current) -> Date { at(9, 0, now, calendar) }

    private static func at(_ h: Int, _ m: Int, _ now: Date, _ c: Calendar) -> Date {
        c.date(byAdding: .minute, value: h * 60 + m, to: c.startOfDay(for: now)) ?? now
    }

    /// 今 出す べき 形(出さない 時間帯は nil)
    static func phase(now: Date, shots: Int, shotYesterday: Bool, night: Bool, morning: Bool, calendar: Calendar = .current) -> LattagLiveAttributes.Phase? {
        if night, shots < 3 {
            if now >= lastCall(now, calendar: calendar), now < lightsOut(now, calendar: calendar) { return .lastCall }
            if now >= nightStart(now, calendar: calendar), now < lastCall(now, calendar: calendar) { return .film }
        }
        if morning, shotYesterday {
            if now >= morningStart(now, calendar: calendar), now < opens(now, calendar: calendar) { return .opening }
        }
        return nil
    }
}
#endif
