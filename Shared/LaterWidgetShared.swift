import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// アプリとウィジェット(拡張)の両方でコンパイルする。アプリの型には依存しない。
// 写真そのもの・他の人の名前・写真・タグは、ここに入れない(ロック画面でも見えるため)。

enum LaterWidgetShared {
    static let appGroup = "group.com.tatsukikitagawa.laternew2"
    static let snapshotKey = "laterWidgetSnapshot"

    static let sceneKind = "LaterScene"
    static let todayKind = "LaterToday"
    static let yesterdayKind = "LaterYesterday"
    static let weekKind = "LaterWeek"

    /// タップ先:later://widget/<U|R|D|M>
    static func deepLink(_ phase: LaterWidgetPhase) -> URL {
        URL(string: "later://widget/\(phase.rawValue)")!
    }
}

// MARK: - 共有する5つの値

struct LaterWidgetSnapshot: Codable, Equatable {
    /// 今日の撮影時刻
    var lastShotAt: Date?
    /// 昨日の写真があるか
    var hasYesterday: Bool
    /// 今日、昨日をひらいたか
    var openedYesterday: Bool
    /// 直近7日(今日をのぞく6日分)に撮った / 撮らなかった。古い順
    var history: [Bool]
    /// 「今日」の判定用(9:00 区切りの日付)
    var dayKey: String

    static let empty = LaterWidgetSnapshot(lastShotAt: nil, hasYesterday: false, openedYesterday: false, history: Array(repeating: false, count: 6), dayKey: "")

    /// App Group の値が空(初回)でも、クラッシュせず空の値を返す(→ U 状態)
    static func load(defaults: UserDefaults? = UserDefaults(suiteName: LaterWidgetShared.appGroup)) -> LaterWidgetSnapshot {
        guard let data = defaults?.data(forKey: LaterWidgetShared.snapshotKey),
              let snapshot = try? JSONDecoder().decode(LaterWidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }

    func save(defaults: UserDefaults? = UserDefaults(suiteName: LaterWidgetShared.appGroup)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: LaterWidgetShared.snapshotKey)
    }
}

// MARK: - 日の区切り(9:00 開始・24:00 消灯。「今日」は 9:00〜翌 8:59)

enum LaterWidgetDay {
    static let openingHour = 9

    /// いまの「今日」が始まった 9:00
    static func start(of now: Date, calendar: Calendar = .current) -> Date {
        let nine = calendar.date(bySettingHour: openingHour, minute: 0, second: 0, of: now) ?? now
        if now >= nine { return nine }
        return calendar.date(byAdding: .day, value: -1, to: nine) ?? nine
    }

    /// 消灯(24:00)
    static func lightsOut(of now: Date, calendar: Calendar = .current) -> Date {
        let start = start(of: now, calendar: calendar)
        return calendar.date(byAdding: .hour, value: 24 - openingHour, to: start) ?? start
    }

    /// 次の 9:00
    static func nextOpening(after now: Date, calendar: Calendar = .current) -> Date {
        let start = start(of: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start
    }

    static func key(for now: Date, calendar: Calendar = .current) -> String {
        let start = start(of: now, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 日数の差(key の日付どうし)
    static func daysBetween(_ older: String, _ newer: String) -> Int? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let a = formatter.date(from: older), let b = formatter.date(from: newer) else { return nil }
        return Int((b.timeIntervalSince(a) / 86_400).rounded())
    }
}

// MARK: - 状態(時刻だけで決まる)

enum LaterWidgetPhase: String, CaseIterable, Codable {
    /// 撮る前(9:00〜24:00 で未撮影)
    case U
    /// 昨日がひらける(撮影後・昨日あり・まだひらいていない)
    case R
    /// 現像中(撮影後・昨日をひらいた、または昨日がない)
    case D
    /// 撮れなかった夜(24:00 を過ぎて未撮影)
    case M
}

struct LaterWidgetState: Equatable {
    let phase: LaterWidgetPhase
    let now: Date
    let shotAt: Date?
    let hasYesterday: Bool
    let openedYesterday: Bool
    /// 7日分(古い順。最後が今日)
    let week: [Bool]

    var dayStart: Date { LaterWidgetDay.start(of: now) }
    var lightsOut: Date { LaterWidgetDay.lightsOut(of: now) }
    var nextOpening: Date { LaterWidgetDay.nextOpening(after: now) }

    /// 現像の進み:撮影時刻 → 翌 9:00
    var developProgress: Double {
        guard let shotAt else { return 0 }
        let total = nextOpening.timeIntervalSince(shotAt)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(shotAt) / total))
    }

    var developPercent: Int { Int((developProgress * 100).rounded(.down)) }

    /// 撮る前:9:00 → 24:00 の進み(月が沈む)
    var dayProgress: Double {
        let total = lightsOut.timeIntervalSince(dayStart)
        return min(1, max(0, now.timeIntervalSince(dayStart) / total))
    }

    static func derive(_ snapshot: LaterWidgetSnapshot, now: Date, calendar: Calendar = .current) -> LaterWidgetState {
        let key = LaterWidgetDay.key(for: now, calendar: calendar)
        var shotAt: Date?
        var hasYesterday = false
        var opened = false
        var history = snapshot.history

        if snapshot.dayKey == key {
            shotAt = snapshot.lastShotAt
            hasYesterday = snapshot.hasYesterday
            opened = snapshot.openedYesterday
        } else if let gap = LaterWidgetDay.daysBetween(snapshot.dayKey, key), gap > 0 {
            // 9:00 をまたいだ:前の「今日」が「昨日」になる(アプリが開かれるまでの、つなぎ)
            hasYesterday = gap == 1 && snapshot.lastShotAt != nil
            history += [snapshot.lastShotAt != nil] + Array(repeating: false, count: max(0, gap - 1))
        } else {
            history = []
        }
        history = Array((Array(repeating: false, count: 6) + history).suffix(6))

        let phase: LaterWidgetPhase
        if shotAt != nil {
            phase = hasYesterday && !opened ? .R : .D
        } else {
            phase = now >= LaterWidgetDay.lightsOut(of: now, calendar: calendar) ? .M : .U
        }
        return LaterWidgetState(phase: phase, now: now, shotAt: shotAt, hasYesterday: hasYesterday, openedYesterday: opened, week: history + [shotAt != nil])
    }
}

// MARK: - ライブアクティビティ

#if canImport(ActivityKit)
struct LaterActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var hasYesterday: Bool
        var openedYesterday: Bool
    }

    /// 撮影時刻(現像のはじまり)
    var shotAt: Date
    /// 現像が終わる 9:00
    var developAt: Date
}
#endif

// MARK: - アプリ側(撮影・昨日をひらく・日付が変わる → 値を書いて、ウィジェットとライブアクティビティを更新)

#if !WIDGET_EXTENSION
import WidgetKit

@MainActor
enum LaterWidgetBridge {
    /// ライブアクティビティの上限(iOS)
    static let activityLimit: TimeInterval = 8 * 3600
    /// 「撮った直後」とみなす長さ(これより古い撮影では、新しく始めない)
    static let freshShot: TimeInterval = 10 * 60

    static func update(captureDates: [Date], hasYesterday: Bool, openedYesterday: Bool, now: Date = Date()) {
        let calendar = Calendar.current
        let start = LaterWidgetDay.start(of: now, calendar: calendar)
        let shot = captureDates.filter { $0 >= start && $0 <= now }.max()
        let history: [Bool] = (1...6).reversed().map { offset in
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? start
            return captureDates.contains { $0 >= dayStart && $0 < dayEnd }
        }
        let snapshot = LaterWidgetSnapshot(
            lastShotAt: shot,
            hasYesterday: hasYesterday,
            openedYesterday: openedYesterday,
            history: history,
            dayKey: LaterWidgetDay.key(for: now, calendar: calendar)
        )
        if snapshot != LaterWidgetSnapshot.load() {
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        updateActivity(snapshot, now: now)
    }

    /// 撮った直後に始め、ひらいたとき・状態が変わったときに更新し、別の日・8時間を過ぎたら終える
    private static func updateActivity(_ snapshot: LaterWidgetSnapshot, now: Date) {
        #if canImport(ActivityKit)
        let activities = Activity<LaterActivityAttributes>.activities
        for activity in activities where activity.attributes.shotAt != snapshot.lastShotAt || now >= activity.attributes.developAt {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        guard let shot = snapshot.lastShotAt, now.timeIntervalSince(shot) < activityLimit,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let developAt = LaterWidgetDay.nextOpening(after: shot)
        let state = LaterActivityAttributes.ContentState(hasYesterday: snapshot.hasYesterday, openedYesterday: snapshot.openedYesterday)
        let content = ActivityContent(state: state, staleDate: min(shot.addingTimeInterval(activityLimit), developAt))
        if let current = activities.first(where: { $0.attributes.shotAt == shot }) {
            if current.content.state != state {
                Task { await current.update(content) }
            }
        } else if now.timeIntervalSince(shot) < freshShot {
            _ = try? Activity.request(attributes: LaterActivityAttributes(shotAt: shot, developAt: developAt), content: content, pushType: nil)
        }
        #endif
    }
}
#endif
