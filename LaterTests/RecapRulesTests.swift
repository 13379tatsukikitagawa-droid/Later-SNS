import Foundation
import Testing
@testable import Later_再度

/// P29(v86):Recap の できる しくみ(端末の 中 ・ 冪等)
struct RecapRulesTests {
    private let cal = RecapRules.calendar()
    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))! }
    private func shots(_ list: [(Date, Bool)]) -> [RecapShot] { list.enumerated().map { RecapShot(id: "p\($0.offset)", date: $0.element.0, tag: $0.offset % 2 == 0 ? "夕焼け" : nil, kept: $0.element.1) } }

    @Test func 月曜の九時より前は作らない() {
        let s = shots([(d(2026, 11, 9), false), (d(2026, 11, 10), false), (d(2026, 11, 12), false)])
        #expect(RecapRules.missing(now: d(2026, 11, 16, 8), shots: s, existing: []).filter { $0.kind == .week }.isEmpty)
        #expect(RecapRules.missing(now: d(2026, 11, 16, 9), shots: s, existing: []).filter { $0.kind == .week }.count == 1)
    }

    @Test func 二枚だけの週は作らない() {
        let s = shots([(d(2026, 11, 9), false), (d(2026, 11, 10), false)])
        #expect(RecapRules.missing(now: d(2026, 11, 17), shots: s, existing: []).filter { $0.kind == .week }.isEmpty)
    }

    @Test func 何度よばれても二つにならない() {
        let s = shots([(d(2026, 11, 9), false), (d(2026, 11, 10), true), (d(2026, 11, 12), false), (d(2026, 11, 13), false)])
        let first = RecapRules.missing(now: d(2026, 11, 17), shots: s, existing: [])
        #expect(first.count == 1)
        #expect(RecapRules.missing(now: d(2026, 11, 17), shots: s, existing: first).isEmpty)
        #expect(first[0].id == "w-2026-11-09")
        #expect(first[0].shots == 4 && first[0].days == 4 && first[0].kept == 1)
        #expect(first[0].topTag == "夕焼け")
    }

    @Test func 月のRecapは一日一枚で最大三十枚() {
        var list: [(Date, Bool)] = []
        for day in 1...31 { list.append((d(2026, 10, day, 9), false)); list.append((d(2026, 10, day, 18), day == 5)) }
        let s = shots(list)
        let m = RecapRules.missing(now: d(2026, 11, 1, 9), shots: s, existing: []).first { $0.kind == .month }
        #expect(m != nil)
        #expect(m!.photoIDs.count == 30)
        #expect(m!.id == "m-2026-10")
        #expect(RecapRules.missing(now: d(2026, 11, 1, 8), shots: s, existing: []).first { $0.kind == .month } == nil)
    }

    @Test func 写真が消えたら条件を割るRecapは消す() {
        let s = shots([(d(2026, 11, 9), false), (d(2026, 11, 10), false), (d(2026, 11, 12), false), (d(2026, 11, 13), false)])
        let m = RecapRules.missing(now: d(2026, 11, 17), shots: s, existing: [])[0]
        #expect(RecapRules.pruned(m, available: Set(m.photoIDs.dropLast()))?.photoIDs.count == 3)
        #expect(RecapRules.pruned(m, available: Set(m.photoIDs.prefix(2))) == nil)
    }

    @Test func 作成中は何日目かとできる日() {
        let sun = RecapRules.building(now: d(2026, 11, 15))
        #expect(sun.dayNumber == 7 && sun.daysLeft == 0 && sun.dueText == "あした 9:00 に できる")
        let tue = RecapRules.building(now: d(2026, 11, 17))
        #expect(tue.dayNumber == 2 && tue.daysLeft == 5)
        #expect(RecapRules.nextMonday9(after: d(2026, 11, 17)) == d(2026, 11, 23, 9))
    }
}
