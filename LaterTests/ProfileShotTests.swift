import Foundation
import Testing
@testable import Later_再度

/// Profileに出す写真の判定(ProfileShot)。点のフィールド・ビューア・レールが共通で使う。
@MainActor
struct ProfileShotTests {
    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    /// 2026-10-03 を基準日とする。
    static func date(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        tokyo.date(from: DateComponents(year: 2026, month: 10, day: 3 + dayOffset, hour: hour, minute: minute))!
    }

    static let group = ProfileShareGroup(name: "よいしょー", otherMemberCount: 4)

    static func source(_ dayOffset: Int, groups: [ProfileShareGroup] = [group], mondo: Bool = false) -> ProfileShot.Source {
        let captured = date(dayOffset, 12)
        let c = tokyo.dateComponents([.year, .month, .day], from: captured)
        return ProfileShot.Source(
            dayKey: String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!),
            captureDate: captured,
            colorHex: "FFAA66",
            locationName: "杉並区",
            tags: ["空"],
            groups: groups,
            isOnMondo: mondo
        )
    }

    @Test func groupに共有した日だけを古い順に出す() {
        let sources = [Self.source(-1), Self.source(-3, groups: []), Self.source(-2)]
        let shots = ProfileShot.visibleShots(from: sources, now: Self.date(0, 12), calendar: Self.tokyo)
        #expect(shots.map(\.date) == [Self.date(-2, 12), Self.date(-1, 12)])
    }

    @Test func 七日すぎた写真は出さない() {
        // 9/26 に撮った写真は 10/03 9:00 に消える
        let sources = (-8...0).map { Self.source($0) }
        let shots = ProfileShot.visibleShots(from: sources, now: Self.date(0, 12), calendar: Self.tokyo)
        #expect(shots.count == 7)
        #expect(shots.first?.remainingDays == 1)
        #expect(shots.first?.remainingText == "あしたの朝、消えます")
        #expect(shots.dropFirst().first?.remainingText == "あと2日で、消えます")
    }

    @Test func 撮った翌朝9時にひらく() {
        let sources = [Self.source(-1), Self.source(0)]
        let before = ProfileShot.visibleShots(from: sources, now: Self.date(0, 8, 59), calendar: Self.tokyo)
        // 10/03 8:59 の時点で、10/02 の1枚はまだひらいていない(10/03 の1枚は未来なので出ない)
        #expect(before.map(\.opened) == [false])
        let after = ProfileShot.visibleShots(from: sources, now: Self.date(0, 13), calendar: Self.tokyo)
        #expect(after.map(\.opened) == [true, false])
        #expect(after.last?.isToday == true)
    }

    @Test func ひらいた日は投稿した1枚だけ() {
        var pending = Self.source(-1)
        pending.isPosted = false
        var today = Self.source(0)
        today.isPosted = false
        let shots = ProfileShot.visibleShots(from: [Self.source(-2), pending, today], now: Self.date(0, 13), calendar: Self.tokyo)
        // 昨日の未決定は出さない。今日の1枚(まだひらいていない)は出す
        #expect(shots.map(\.date) == [Self.date(-2, 12), Self.date(0, 12)])
    }

    @Test func レールは右端が今日の7枠() {
        let keys = ProfileShot.railDayKeys(now: Self.date(0, 12), calendar: Self.tokyo)
        #expect(keys == ["2026-09-27", "2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03"])
    }

    @Test func フィルムの日付() {
        #expect(ProfileShot.filmStamp(for: Self.date(0, 12), calendar: Self.tokyo) == "'26 10 03")
    }

    @Test func 共有先ピルの文言() {
        let other = ProfileShareGroup(name: "かぞく", otherMemberCount: 2)
        let third = ProfileShareGroup(name: "ゼミ", otherMemberCount: 9)
        #expect(ProfileShot.shareSummary(groups: [Self.group], isOnMondo: true) == "よいしょー ・ Mondo")
        #expect(ProfileShot.shareSummary(groups: [Self.group], isOnMondo: false) == "よいしょー")
        #expect(ProfileShot.shareSummary(groups: [Self.group, other, third], isOnMondo: false) == "よいしょー ＋2")
        #expect(ProfileShot.spokenShareTargets(groups: [Self.group], isOnMondo: true) == "よいしょー、Mondo")
    }
}
