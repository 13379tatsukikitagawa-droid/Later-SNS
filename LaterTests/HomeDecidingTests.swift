import Foundation
import Testing
@testable import Later_再度

/// deciding(昨日の自分の1枚を、投稿するか選ぶ)の判定表。時計を差しかえて確かめる。
@MainActor
struct HomeDecidingTests {
    static let tokyo = HomeStateTests.tokyo

    static func date(_ dayOffset: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        HomeStateTests.date(dayOffset, hour, minute, second)
    }

    private func resolve(_ now: Date, shots: [Date], opened: String? = nil, decision: YesterdayDecision?) -> HomeState {
        HomeState.resolve(now: now, myCaptureDates: shots, hasDeposited: true, openedWindowKey: opened, yesterdayDecision: decision, calendar: Self.tokyo)
    }

    struct Row: CustomTestStringConvertible, Sendable {
        let label: String
        let shotToday: Bool
        let decision: YesterdayDecision?
        let opened: Bool
        let expected: String
        var testDescription: String { label }
    }

    /// 昼(10:00)の表:撮影前後 × 昨日の写真あり/なし × undecided / posted / skipped
    static let rows: [Row] = [
        Row(label: "撮影前・昨日なし", shotToday: false, decision: nil, opened: false, expected: "dawn"),
        Row(label: "撮影前・未決定", shotToday: false, decision: .undecided, opened: false, expected: "dawn"),
        Row(label: "撮影後・昨日なし", shotToday: true, decision: nil, opened: false, expected: "ready"),
        Row(label: "撮影後・未決定", shotToday: true, decision: .undecided, opened: false, expected: "deciding"),
        Row(label: "撮影後・投稿した", shotToday: true, decision: .posted, opened: false, expected: "ready"),
        Row(label: "撮影後・投稿しない", shotToday: true, decision: .skipped, opened: false, expected: "ready"),
        Row(label: "撮影後・投稿した・ひらいた(1枚目・あと2こま)", shotToday: true, decision: .posted, opened: true, expected: "more"),
        Row(label: "撮影後・未決定・ひらいた記録あり", shotToday: true, decision: .undecided, opened: true, expected: "deciding"),
    ]

    @Test(arguments: rows)
    func table(_ row: Row) {
        let now = Self.date(0, 10, 0)
        let yesterday = Self.date(-1, 20, 0)
        let today = Self.date(0, 9, 30)
        let shots = row.shotToday ? [yesterday, today] : [yesterday]
        let key = row.opened ? DailyWindow.key(for: now, calendar: Self.tokyo) : nil
        #expect(resolve(now, shots: shots, opened: key, decision: row.decision).kind == row.expected)
    }

    /// 夜は deciding にならない(撮れない・決める時間ではない)
    @Test func nightIgnoresDecision() {
        let state = resolve(Self.date(1, 1, 0), shots: [Self.date(0, 9, 30)], decision: .undecided)
        #expect(state == .night)
    }

    /// 決定は窓ごと:9:00 をまたぐと「昨日」が1つ進み、決める対象が変わる
    @Test func decisionResetsAtNine() {
        // 10/02 に撮った1枚(10/03 が「昨日の1枚」を決める日)
        let photoDay = Self.date(-1, 20, 0)
        // 10/03 08:59(夜)は、前の窓をまだ見ている
        let before = DailyWindow.yesterday(for: Self.date(0, 8, 59), calendar: Self.tokyo)
        #expect(!(photoDay >= before.open && photoDay < before.close))
        // 10/03 09:00 になると、10/02 の窓が「昨日」になる
        let atNine = DailyWindow.yesterday(for: Self.date(0, 9, 0), calendar: Self.tokyo)
        #expect(photoDay >= atNine.open && photoDay < atNine.close)
        // 10/04 09:00 には、もう「昨日」ではない(決めなければ、ここで消える)
        let nextDay = DailyWindow.yesterday(for: Self.date(1, 9, 0), calendar: Self.tokyo)
        #expect(photoDay < nextDay.open)
    }

    @Test func decisionFromPhotos() {
        #expect(YesterdayDecision.resolve(yesterdayOwnPosted: []) == nil)
        #expect(YesterdayDecision.resolve(yesterdayOwnPosted: [false, false]) == .undecided)
        #expect(YesterdayDecision.resolve(yesterdayOwnPosted: [true, true]) == .posted)
        #expect(YesterdayDecision.resolve(yesterdayOwnPosted: [true, false]) == .undecided)
    }

    @Test func moonAndMondoWhileDeciding() {
        let state = HomeState.deciding(shotAt: Self.date(0, 9, 30))
        #expect(state.moonPlan(yesterday: .count(3)) == .decide)
        #expect(state.mondoGate == .enter)
        #expect(!state.canShoot)
    }
}
