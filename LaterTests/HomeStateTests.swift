import Foundation
import Testing
@testable import Later_再度

/// HomeState(第2章)の判定表と、時間のカプセル・9:00のリセットを、時計を差しかえて確かめる。
@MainActor
struct HomeStateTests {
    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// 2026-10-03 を基準日 D とする。dayOffset で前後の日。
    static func date(_ dayOffset: Int, _ hour: Int, _ minute: Int, _ second: Int = 0, calendar: Calendar = tokyo) -> Date {
        let d = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3 + dayOffset, hour: hour, minute: minute, second: second))!
        return d
    }

    struct Case: CustomTestStringConvertible, Sendable {
        let label: String
        let dayOffset: Int
        let hour: Int
        let minute: Int
        let isNight: Bool
        var testDescription: String { label }
    }

    static let times: [Case] = [
        Case(label: "08:59", dayOffset: 0, hour: 8, minute: 59, isNight: true),
        Case(label: "09:00", dayOffset: 0, hour: 9, minute: 0, isNight: false),
        Case(label: "09:06", dayOffset: 0, hour: 9, minute: 6, isNight: false),
        Case(label: "23:59", dayOffset: 0, hour: 23, minute: 59, isNight: false),
        Case(label: "00:00", dayOffset: 1, hour: 0, minute: 0, isNight: true),
        Case(label: "00:01", dayOffset: 1, hour: 0, minute: 1, isNight: true),
    ]

    private func resolve(_ now: Date, shots: [Date], opened: String?, hasDeposited: Bool = true) -> HomeState {
        HomeState.resolve(now: now, myCaptureDates: shots, hasDeposited: hasDeposited, openedWindowKey: opened, calendar: Self.tokyo)
    }

    /// 時刻 × 撮影あり・なし × ひらいた・ひらいてない
    static let flags: [Flags] = [Flags(shot: false, opened: false), Flags(shot: false, opened: true), Flags(shot: true, opened: false), Flags(shot: true, opened: true)]

    struct Flags: CustomTestStringConvertible, Sendable {
        let shot: Bool
        let opened: Bool
        var testDescription: String { "撮影\(shot ? "あり" : "なし")・\(opened ? "ひらいた" : "ひらいてない")" }
    }

    @Test(arguments: times, flags)
    func decisionTable(_ c: Case, _ f: Flags) {
        let shot = f.shot, opened = f.opened
        let now = Self.date(c.dayOffset, c.hour, c.minute)
        let latest = DailyWindow.latest(for: now, calendar: Self.tokyo)
        // 直近の窓の中で、いまより前の時刻に撮る(昼は窓がひらいた瞬間、夜は前の窓の20:00)
        let shotAt = c.isNight ? latest.open.addingTimeInterval(11 * 3600) : latest.open
        // それより前の日にも1枚あり、初日ではない
        let past = latest.open.addingTimeInterval(-2 * 86400)
        let shots = shot ? [past, shotAt] : [past]
        let key = opened ? DailyWindow.key(for: now, calendar: Self.tokyo) : nil

        let state = resolve(now, shots: shots, opened: key)

        switch (c.isNight, shot, opened) {
        case (true, true, _): #expect(state == .night)
        case (true, false, _): #expect(state == .rest)
        case (false, false, _): #expect(state == .dawn)
        case (false, true, false): #expect(state == .ready(shotAt: shotAt))
        // ひらいたあと、1枚だけなら、まだ2こま撮れる(more)
        case (false, true, true): #expect(state == .more(shotAt: shotAt, remaining: 2))
        }
    }

    @Test func firstDay() {
        #expect(resolve(Self.date(0, 9, 6), shots: [], opened: nil, hasDeposited: false) == .first)
        #expect(resolve(Self.date(0, 9, 6), shots: [], opened: nil, hasDeposited: true) == .dawn)
    }

    /// 9:00ちょうどで「ひらいた」がリセットされる(前の窓のキーは、新しい窓では効かない)。
    @Test func openedResetsAtNine() {
        let yesterdayShot = Self.date(-1, 20, 0)
        let openedYesterday = DailyWindow.key(for: Self.date(-1, 22, 0), calendar: Self.tokyo)

        // 08:59 はまだ前の窓(夜)
        #expect(resolve(Self.date(0, 8, 59), shots: [yesterdayShot], opened: openedYesterday) == .night)
        // 09:00 になったら、撮っていない → dawn(前日の「ひらいた」は残らない)
        #expect(resolve(Self.date(0, 9, 0), shots: [yesterdayShot], opened: openedYesterday) == .dawn)
        // 09:00 に撮った → ready(opened ではない)
        let todayShot = Self.date(0, 9, 0)
        #expect(resolve(Self.date(0, 9, 1), shots: [yesterdayShot, todayShot], opened: openedYesterday) == .ready(shotAt: todayShot))
        #expect(DailyWindow.key(for: Self.date(0, 8, 59, 59), calendar: Self.tokyo) != DailyWindow.key(for: Self.date(0, 9, 0), calendar: Self.tokyo))
    }

    /// 端末の時計を戻して、撮影時刻が「いま」より後になっても、撮ったことにしない。
    @Test func clockMovedBackwards() {
        let futureShot = Self.date(0, 15, 0)
        #expect(resolve(Self.date(0, 10, 0), shots: [Self.date(-1, 20, 0), futureShot], opened: nil) == .dawn)
    }

    /// タイムゾーンを変えても、その土地の時刻で判定する(壊れない)。
    @Test func timeZoneChange() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // 東京の 09:06 は、ニューヨークでは前日の 20:06(昼)
        let now = Self.date(0, 9, 6)
        let shot = Self.date(0, 9, 3)
        #expect(HomeState.resolve(now: now, myCaptureDates: [shot], hasDeposited: true, openedWindowKey: nil, calendar: newYork) == .ready(shotAt: shot))
        // 東京の 14:00 は、ニューヨークでは 01:00(夜)。直近の窓(前日)に撮っているので night
        let night = Self.date(0, 14, 0)
        #expect(HomeState.resolve(now: night, myCaptureDates: [shot], hasDeposited: true, openedWindowKey: nil, calendar: newYork) == .night)
    }

    // MARK: - 時間のカプセル

    @Test(arguments: [
        (0, 9, 6, 20, "消灯まで 14:53"),
        (0, 9, 6, 0, "消灯まで 14:54"),
        (0, 9, 0, 0, "消灯まで 15:00"),
        (0, 23, 59, 0, "消灯まで 00:01"),
        (1, 0, 0, 0, "ひらくまで 09:00"),
        (1, 0, 1, 0, "ひらくまで 08:59"),
        (0, 8, 59, 0, "ひらくまで 00:01"),
    ])
    func capsule(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int, _ expected: String) {
        #expect(DailyWindow.capsuleText(now: Self.date(day, hour, minute, second), calendar: Self.tokyo) == expected)
    }

    /// 昼のカプセルは、24:00直前の1分以外で 00:00 にならない
    @Test func capsuleNeverZeroDuringDay() {
        var t = Self.date(0, 9, 0)
        let end = Self.date(0, 23, 59)
        while t < end {
            #expect(DailyWindow.capsule(now: t, calendar: Self.tokyo).minutes > 0)
            t = t.addingTimeInterval(7 * 60 + 13)
        }
    }

    // MARK: - 月

    @Test func moonPlan() {
        let shot = Self.date(0, 10, 0)
        #expect(HomeState.dawn.moonPlan(yesterday: .count(3)) == .shoot)
        #expect(HomeState.first.moonPlan(yesterday: .count(0)) == .shoot)
        #expect(HomeState.ready(shotAt: shot).moonPlan(yesterday: .count(3)) == .open)
        #expect(HomeState.ready(shotAt: shot).moonPlan(yesterday: .loading) == .open)
        if case .locked = HomeState.ready(shotAt: shot).moonPlan(yesterday: .count(0)) {} else { Issue.record("ひらくものがない ready は月をロックする") }
        #expect(HomeState.opened(shotAt: shot).moonPlan(yesterday: .count(3)) == .review)
        #expect(HomeState.more(shotAt: shot, remaining: 2).moonPlan(yesterday: .count(3)) == .shoot)
        if case .locked = HomeState.night.moonPlan(yesterday: .count(3)) {} else { Issue.record("夜は月をロックする") }
    }

    // MARK: - 現像

    @Test func developDensity() {
        let shot = Self.date(0, 9, 0)
        #expect(DevelopDensity.litDots(capturedAt: shot, now: Self.date(0, 9, 30)) == 1)
        #expect(DevelopDensity.litDots(capturedAt: shot, now: Self.date(0, 14, 20)) == 6)
        #expect(DevelopDensity.litDots(capturedAt: shot, now: Self.date(1, 9, 30)) == 24)
        #expect(DevelopDensity.density(1) == 1)
        #expect(abs(DevelopDensity.density(0.5) - pow(0.5, 0.75)) < 1e-9)
    }
}
