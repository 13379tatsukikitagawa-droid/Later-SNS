import Foundation
import Testing
@testable import Later_再度

/// ヘッダーの「消灯まで」の残り時間の書き方(12h 56m / 56m / 00:56:12)
@MainActor
struct LaterHeaderTimeTests {
    private static let cal = HomeStateTests.tokyo
    private static func at(_ hour: Int, _ minute: Int, _ second: Int = 0, day: Int = 0) -> Date {
        HomeStateTests.date(day, hour, minute, second)
    }

    @Test func moreThanAnHourShowsHoursAndMinutes() {
        // 11:03:30 → 消灯まで 12時間56分30秒 → 12h 56m
        #expect(LaterHeaderTime.text(now: Self.at(11, 3, 30), calendar: Self.cal) == "12h 56m")
        #expect(LaterHeaderTime.text(now: Self.at(9, 0), calendar: Self.cal) == "15h 0m")
        #expect(!LaterHeaderTime.isLastHour(now: Self.at(11, 3, 30), calendar: Self.cal))
    }

    @Test func lessThanAnHourShowsMinutesOnly() {
        // 22:03:30 → 残り 1時間56分 ではなく、22:03 → 1h 56m。22:30 → 1h 30m。
        #expect(LaterHeaderTime.text(now: Self.at(22, 3, 30), calendar: Self.cal) == "1h 56m")
        #expect(LaterHeaderTime.text(now: Self.at(22, 30), calendar: Self.cal) == "1h 30m")
        // 夜(0:00〜9:00)は、ひらくまでの分。8:04 → 55m(最後の1時間の黒いピルは昼だけ)
        let night = Self.at(8, 4, 20, day: 1)
        #expect(LaterHeaderTime.text(now: night, calendar: Self.cal) == "55m")
        #expect(!LaterHeaderTime.isLastHour(now: night, calendar: Self.cal))
    }

    @Test func lastHourShowsSeconds() {
        // 23:03:48 → 00:56:12
        let now = Self.at(23, 3, 48)
        #expect(LaterHeaderTime.isLastHour(now: now, calendar: Self.cal))
        #expect(LaterHeaderTime.text(now: now, calendar: Self.cal) == "00:56:12")
        #expect(LaterHeaderTime.text(now: Self.at(23, 59, 59), calendar: Self.cal) == "00:00:01")
    }

    @Test func boundaryAt2300() {
        // 22:59:59 はまだ分の書き方、23:00:00 から秒つき
        #expect(LaterHeaderTime.text(now: Self.at(22, 59, 59), calendar: Self.cal) == "1h 0m")
        #expect(!LaterHeaderTime.isLastHour(now: Self.at(22, 59, 59), calendar: Self.cal))
        #expect(LaterHeaderTime.isLastHour(now: Self.at(23, 0), calendar: Self.cal))
        #expect(LaterHeaderTime.text(now: Self.at(23, 0), calendar: Self.cal) == "01:00:00")
        // 0:00 は夜(最後の1時間ではない)
        #expect(!LaterHeaderTime.isLastHour(now: Self.at(0, 0, day: 1), calendar: Self.cal))
    }

    @Test func spokenDuration() {
        #expect(LaterHeaderTime.spokenDuration(776) == "12時間56分")
        #expect(LaterHeaderTime.spokenDuration(56) == "56分")
        #expect(LaterHeaderTime.spokenDuration(120) == "2時間")
    }
}
