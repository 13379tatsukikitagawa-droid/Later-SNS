import Foundation
import SwiftUI
import Testing
@testable import Later_再度

/// v14:テーマの時刻 / 今日のフィルム / ためて つつく / 現像ページャー / 触覚 / 地球儀の回転 / カレンダー / ともだち / チェキ フィード
@MainActor
struct V14Tests {
    private let calendar = Calendar.current

    private func date(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        // 特別な日(0:00〜9:00 も 撮れる日など)に かからない、ふつうの日を 基準にする
        let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!
        let day = calendar.date(byAdding: .day, value: dayOffset, to: base)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    // MARK: 1 テーマ

    @Test func 黒は21時から9時まで_撮影の有無に関係ない() {
        #expect(!ThemeClock.isNight(date(0, 16, 30)))
        #expect(ThemeClock.isNight(date(0, 22)))
        #expect(ThemeClock.isNight(date(0, 21)))
        #expect(!ThemeClock.isNight(date(0, 9)))
        #expect(ThemeClock.nightStartHour == 21 && ThemeClock.dayStartHour == 9)
        // 撮影したかどうかで、今日のホームを切りかえない
        for state in [HomeState.first, .dawn, .ready(shotAt: Date()), .opened(shotAt: Date()), .more(shotAt: Date(), remaining: 1), .night, .rest] {
            #expect(state.usesChicHome)
        }
        // 撮影の「おやすみ時間」は 0:00〜8:59 のまま(21時台は黒いが撮れる)
        #expect(!CaptureClock.isRestTime(date(0, 22)))
        #expect(CaptureClock.isRestTime(date(0, 6)))
    }

    // MARK: ⓪ 今日のフィルム

    private func shot(_ id: String, _ at: Date) -> TodayShot { TodayShot(id: id, takenAt: at, city: "渋谷区") }

    @Test func チェキ枠は_撮った分_次_あとで() {
        let frames = TodayFilmRules.frames(shots: [shot("a", date(0, 10))], canShoot: true)
        #expect(frames.count == 3)
        if case .shot(_, 0) = frames[0] {} else { Issue.record("1つ目は撮った枠") }
        #expect(frames[1] == .next(index: 1))
        #expect(frames[2] == .later(index: 2))
        let none = TodayFilmRules.frames(shots: [], canShoot: false)
        #expect(none.allSatisfy { if case .later = $0 { return true } else { return false } })
        #expect(TodayFilmRules.tilt(index: 0) == -3 && TodayFilmRules.tilt(index: 2) == 3)
    }

    @Test func 月のことばと_あと何時間() {
        #expect(TodayFilmRules.moonTitle(shots: 0) == "今日を撮る")
        #expect(TodayFilmRules.moonTitle(shots: 1) == "もう1枚 撮る")
        #expect(TodayFilmRules.moonSubtitle(shots: 1) == "●●○  のこり 2こま")
        #expect(TodayFilmRules.moonTitle(shots: 3) == "9:00に、ひらきます")
        #expect(TodayFilmRules.moonSubtitle(shots: 3) == "今日は、ここまで")
        let r = TodayFilmRules.remaining(now: date(0, 16, 30))
        #expect(r.hours == 16 && r.minutes == 30)
        #expect(TodayFilmRules.nextRevealDate(after: date(0, 16, 30)) == date(1, 9))
    }

    @Test func 朝焼けアーチの太陽() {
        #expect(TodayFilmRules.archProgress(shots: [], now: Date()) == nil)
        let p = TodayFilmRules.archProgress(shots: [shot("a", date(0, 9))], now: date(0, 21))!
        #expect(abs(p - 0.5) < 0.001)
    }

    // MARK: ⑧ 現像ページャー

    @Test func 現像ページャー_しきい値と端() {
        let next = DevelopPagerRules.page(after: 0, drag: -80, count: 3)
        #expect(next.page == 1 && !next.hitEnd)
        let end = DevelopPagerRules.page(after: 2, drag: -80, count: 3)
        #expect(end.page == 2 && end.hitEnd)
        let first = DevelopPagerRules.page(after: 0, drag: 80, count: 3)
        #expect(first.page == 0 && first.hitEnd)
        let stay = DevelopPagerRules.page(after: 1, drag: 40, count: 3)
        #expect(stay.page == 1 && !stay.hitEnd)
        let look = DevelopPagerRules.look(index: 1, peek: 0)
        #expect(look.blur == 8 && look.saturation == 0.5 && look.fog == 0.58)
        // のぞいても、完全には見せない
        let peek = DevelopPagerRules.look(index: 2, peek: 1)
        #expect(peek.blur >= 3 && peek.fog >= 0.2)
    }

    // MARK: 2 触覚

    @Test func heartは長押しで520msから190msへ() {
        #expect(abs(Haptics.heartInterval(progress: 0) - 0.52) < 0.0001)
        #expect(abs(Haptics.heartInterval(progress: 1) - 0.19) < 0.0001)
        #expect(Haptics.Tuning.gaps[.tick] == 0.055 && Haptics.Tuning.gaps[.pop] == 0.09)
        #expect(Haptics.Tuning.scrollGap == 0.07)
        #expect(SquishCurve.keys[1].x == 1.07 && SquishCurve.keys[1].y == 0.9)
    }

    // MARK: ① 地球儀

    @Test func 地球儀は縦にも回り_回転は行列のかけ足し() {
        var r = GlobeRotation.identity
        // 縦にドラッグ(dy)すると、北極(0,1,0)が手前(z)へ倒れる
        r = GlobeRotation.step(r, dx: 0, dy: .pi / 2)
        let pole = GlobeRotation.apply(r, (0, 1, 0))
        #expect(abs(pole.y) < 1e-9 && abs(abs(pole.z) - 1) < 1e-9)
        // 横・縦を何度かけても、長さは 1 のまま(逆さまで破綻しない)
        var m = GlobeRotation.initial
        for i in 0..<500 { m = GlobeRotation.step(m, dx: 0.03 * Double(i % 7), dy: -0.05) }
        let v = GlobeRotation.apply(m, (0.6, 0.0, 0.8))
        #expect(abs((v.x * v.x + v.y * v.y + v.z * v.z) - 1) < 1e-6)
    }

    // MARK: ⑦ カレンダー

    @Test func 七日より古い日は_色だけ() {
        #expect(!LaterCalendarRules.isFaded(dayStart: date(-6, 0), now: date(0, 12)))
        #expect(LaterCalendarRules.isFaded(dayStart: date(-7, 0), now: date(0, 12)))
        let key = ExposureDayStore.dayKey(for: date(-1, 12))
        let months = LaterCalendarRules.months(now: Date(), count: 1, colors: [key: "FF8800"], thumbs: [key])
        let cells = months[0].weeks.flatMap { $0 }
        #expect(cells.count % 7 == 0)
        if calendar.isDate(date(-1, 12), equalTo: Date(), toGranularity: .month) {
            let cell = cells.first { $0.id == key }
            #expect(cell?.thumbed == true)
            #expect(cell?.kind == .shot(colorHex: "FF8800", old: false))
        }
        #expect(LaterCalendarRules.date(fromKey: "2026-11-03") != nil)
    }

    @Test func MEのリール_今日はロック() {
        let reel = MEReelRules.days(exposureDays: [], now: Date())
        #expect(reel.count == 7)
        #expect(reel.allSatisfy { $0.kind == .rest })
        let last = MEReelDay(key: "k", ago: 6, date: Date(), kind: .photo(nil))
        #expect(MEReelRules.note(last) == "あと1日で きえる")
        #expect(MEReelRules.note(MEReelDay(key: "t", ago: 0, date: Date(), kind: .locked)) == "LOCKED")
    }

    // MARK: ⑤ ともだち

    @Test func ともだちは12人まで_相手が12人でもつながれない() {
        #expect(FriendRules.maxFriends == 12)
        #expect(FriendRules.canConnect(myCount: 11, theirCount: 3))
        #expect(!FriendRules.canConnect(myCount: 12, theirCount: 3))
        #expect(!FriendRules.canConnect(myCount: 3, theirCount: 12))
        #expect(FriendRules.fullMessage == "ともだちは 12人まで")
        #expect(FriendRules.isMutual(mine: ["b"], theirs: ["b"], other: "b"))
        #expect(!FriendRules.isMutual(mine: ["b"], theirs: [], other: "b"))
        let url = FriendRules.link(recordName: "_abc")
        #expect(FriendRules.recordName(from: url) == "_abc")
    }

    @Test func 招待カードは_入るを押すまでpending() throws {
        let defaults = try #require(UserDefaults(suiteName: "V14-\(UUID().uuidString)"))
        #expect(InviteCardStore.status("x", defaults: defaults) == .pending)
        InviteCardStore.set(.accepted, for: "x", defaults: defaults)
        #expect(InviteCardStore.status("x", defaults: defaults) == .accepted)
    }

    // MARK: ⑥ チェキ フィード

    @Test func チェキフィードの決まり() {
        #expect(ChekiFeedRules.frameSide == 11 && ChekiFeedRules.frameBottom == 82)
        #expect(ChekiFeedRules.penColor(for: "ゆうやけ") == ChekiFeedRules.penColor(for: "ゆうやけ"))
        #expect(ChekiFeedRules.penColors.count == 6)
        var c = DateComponents(); c.year = 2026; c.month = 11; c.day = 2; c.hour = 12
        #expect(ChekiFeedRules.stamp(Calendar.current.date(from: c)!) == "'26 11 02")
        #expect(ChekiFeedRules.sectionLabel(capturedAt: nil, dayText: nil, isLocked: true, now: Date()) == "きょう ・ 9:00 に ひらく")
        let seed = UUID()
        let a = ViewerPage(id: "a", capturedAt: date(-1, 10), authorSeed: seed, showsAuthor: true)
        let b = ViewerPage(id: "b", capturedAt: date(-1, 15), authorSeed: seed, showsAuthor: true)
        let other = ViewerPage(id: "c", capturedAt: date(-1, 15), authorSeed: UUID(), showsAuthor: true)
        let mondo = ViewerPage(id: "m", capturedAt: date(-1, 15))
        let stacks = ChekiFeedRules.stacks([a, b, other, mondo])
        #expect(stacks.map { $0.map(\.id) } == [["a", "b"], ["c"], ["m"]])
    }

    @Test func 手書きフォントが入っている() {
        #expect(UIFont(name: ChekiFont.handName, size: 20) != nil)
    }
}
