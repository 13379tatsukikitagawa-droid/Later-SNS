import Foundation
import Testing
@testable import Later_再度

/// 【B】前日の 自分の写真は、今日 保存できた 枚数だけ、撮った順に ひらく
@MainActor
struct OwnRevealTests {
    private var tokyo: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    /// ふつうの日(特別な日に かからない)
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func 撮った枚数だけ_古い順にひらく() {
        let y = [date(20, 10), date(20, 13), date(20, 18)]
        let now = date(21, 12)
        // 今日 0枚:前日は ぜんぶ まだ
        #expect(OwnReveal.status(takenAt: y[0], now: now, ownCaptureDates: y, calendar: tokyo) == .waiting(shots: 1))
        #expect(OwnReveal.status(takenAt: y[2], now: now, ownCaptureDates: y, calendar: tokyo) == .waiting(shots: 3))
        // 今日 1枚:いちばん古い 1枚だけ
        let one = y + [date(21, 11)]
        #expect(OwnReveal.status(takenAt: y[0], now: now, ownCaptureDates: one, calendar: tokyo) == .open)
        #expect(OwnReveal.status(takenAt: y[1], now: now, ownCaptureDates: one, calendar: tokyo) == .waiting(shots: 1))
        #expect(OwnReveal.openedYesterdayCount(now: now, ownCaptureDates: one, calendar: tokyo) == 1)
        // グループごとの 写し(同じ時刻)は 1枚
        let copies = one + [date(21, 11), date(20, 10)]
        #expect(OwnReveal.openedYesterdayCount(now: now, ownCaptureDates: copies, calendar: tokyo) == 1)
        // 今日 3枚
        let three = y + [date(21, 9, 30), date(21, 10), date(21, 11)]
        #expect(y.allSatisfy { OwnReveal.status(takenAt: $0, now: now, ownCaptureDates: three, calendar: tokyo) == .open })
    }

    @Test func 今日の写真は9時まで_それより前の日はひらいている() {
        let now = date(21, 12)
        let today = date(21, 10)
        #expect(OwnReveal.status(takenAt: today, now: now, ownCaptureDates: [today], calendar: tokyo) == .developing)
        #expect(OwnReveal.status(takenAt: date(19, 12), now: now, ownCaptureDates: [date(19, 12)], calendar: tokyo) == .open)
    }

    @Test func 九時をすぎたら数えなおす() {
        let y = [date(20, 10), date(20, 13)]
        let shots = y + [date(21, 10), date(21, 11)]
        // 21日のうちは 2枚 ひらく
        #expect(OwnReveal.openedYesterdayCount(now: date(21, 23), ownCaptureDates: shots, calendar: tokyo) == 2)
        // 22日 9:00 をすぎたら、前日(21日)の 2枚は また 0枚から
        #expect(OwnReveal.status(takenAt: date(21, 10), now: date(22, 9, 1), ownCaptureDates: shots, calendar: tokyo) == .waiting(shots: 1))
        // 夜中(0:00〜9:00)は、21日の 写真は まだ 現像中
        #expect(OwnReveal.status(takenAt: date(21, 10), now: date(22, 3), ownCaptureDates: shots, calendar: tokyo) == .developing)
    }

    @Test func 撮った写真が返らなかったら_のこりを戻す() {
        let name = "film-refund-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let now = date(21, 12)
        let counter = FilmCounter(defaults: defaults, clock: { now }, calendar: tokyo, capacity: { _, _ in 3 })
        counter.consume(captureID: UUID(), source: "screen")
        counter.consume(captureID: UUID(), source: "screen")
        counter.refundLast(reason: "test")
        #expect(counter.used == 1)
        #expect(counter.remaining == 2)
    }
}
