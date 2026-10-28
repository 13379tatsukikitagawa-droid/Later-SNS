import CloudKit
import SwiftUI
import Testing
@testable import Later_再度

/// 灯(ともしび)の規則とカレンダーの計算。画面を持たない純粋な部分。
struct LampRulesTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    // MARK: 同じ日・同じ場所で1つだけ

    @Test func firstPressPlacesALamp() {
        let r = LampRules.toggle([], day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "u", now: t0)
        #expect(r.outcome == .placed)
        #expect(r.lamps.count == 1)
        #expect(r.lamps[0].photoRecordName == "p1")
    }

    @Test func pressingAnotherPhotoMovesTheLamp() {
        let a = LampRules.toggle([], day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "u", now: t0)
        let b = LampRules.toggle(a.lamps, day: "2026-10-26", scope: "world", photoRecordName: "p2", userId: "u", now: t0.addingTimeInterval(5))
        #expect(b.outcome == .moved(from: "p1"))
        #expect(b.lamps.count == 1)
        #expect(b.lamps[0].photoRecordName == "p2")
        #expect(b.lamps[0].updatedAt == t0.addingTimeInterval(5))
    }

    @Test func pressingTheSamePhotoCancels() {
        let a = LampRules.toggle([], day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "u", now: t0)
        let b = LampRules.toggle(a.lamps, day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "u", now: t0)
        #expect(b.outcome == .cancelled)
        #expect(b.lamps.isEmpty)
    }

    @Test func scopesDaysAndUsersAreIndependent() {
        var lamps: [Lamp] = []
        lamps = LampRules.toggle(lamps, day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "u", now: t0).lamps
        lamps = LampRules.toggle(lamps, day: "2026-10-26", scope: "groupA", photoRecordName: "g1", userId: "u", now: t0).lamps
        lamps = LampRules.toggle(lamps, day: "2026-10-26", scope: "groupB", photoRecordName: "g2", userId: "u", now: t0).lamps
        lamps = LampRules.toggle(lamps, day: "2026-10-27", scope: "world", photoRecordName: "p9", userId: "u", now: t0).lamps
        lamps = LampRules.toggle(lamps, day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "other", now: t0).lamps
        #expect(lamps.count == 5)
        #expect(Set(lamps.map(\.id)).count == 5)
    }

    @Test func duplicatesAreCollapsedToOne() {
        let dup = [
            Lamp(day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "u", updatedAt: t0),
            Lamp(day: "2026-10-26", scope: "world", photoRecordName: "p2", userId: "u", updatedAt: t0),
        ]
        let r = LampRules.toggle(dup, day: "2026-10-26", scope: "world", photoRecordName: "p3", userId: "u", now: t0)
        #expect(r.lamps.count == 1)
        #expect(r.lamps[0].photoRecordName == "p3")
    }

    @Test func recordNameIsDeterministic() {
        #expect(LampRules.recordName(userHash: "abc", day: "2026-10-26", scope: "world") == "lamp_abc_2026-10-26_world")
        let lamp = Lamp(day: "2026-10-26", scope: "G1", photoRecordName: "p", userId: "abc", updatedAt: t0)
        #expect(lamp.id == "lamp_abc_2026-10-26_G1")
    }

    @Test func remainingCountsWorldPlusGroups() {
        var lamps: [Lamp] = []
        #expect(LampRules.remaining(groupCount: 3, lamps: lamps, day: "d", userId: "u") == 4)
        lamps = LampRules.toggle(lamps, day: "d", scope: "world", photoRecordName: "p", userId: "u", now: t0).lamps
        lamps = LampRules.toggle(lamps, day: "d", scope: "g1", photoRecordName: "p", userId: "u", now: t0).lamps
        #expect(LampRules.remaining(groupCount: 3, lamps: lamps, day: "d", userId: "u") == 2)
        // 移しても数は変わらない
        lamps = LampRules.toggle(lamps, day: "d", scope: "g1", photoRecordName: "q", userId: "u", now: t0).lamps
        #expect(LampRules.remaining(groupCount: 3, lamps: lamps, day: "d", userId: "u") == 2)
        // グループは最大10個
        #expect(LampRules.remaining(groupCount: 30, lamps: [], day: "d", userId: "u") == 11)
        #expect(LampRules.remaining(groupCount: -1, lamps: [], day: "d", userId: "u") == 1)
    }

    // MARK: ともせる条件・締め切り

    @Test func onlyOthersUnlockedPhotosCanBeLit() {
        #expect(LampRules.canLamp(isMine: false, isUnlocked: true, isBlocked: false, shotsToday: 1))
        #expect(!LampRules.canLamp(isMine: true, isUnlocked: true, isBlocked: false, shotsToday: 3))
        #expect(!LampRules.canLamp(isMine: false, isUnlocked: false, isBlocked: false, shotsToday: 3))
        #expect(!LampRules.canLamp(isMine: false, isUnlocked: true, isBlocked: true, shotsToday: 3))
        #expect(!LampRules.canLamp(isMine: false, isUnlocked: true, isBlocked: false, shotsToday: 0))
    }

    @Test func deadlineIsMidnightEndOfTheDayAfterThePhotoDay() {
        // 10/26 の写真は、10/27 の 24:00(= 10/28 0:00)まで
        #expect(LampRules.isOpen(photoDay: "2026-10-26", now: date(2026, 10, 27, 23, 59), calendar: calendar))
        #expect(!LampRules.isOpen(photoDay: "2026-10-26", now: date(2026, 10, 28, 0, 0), calendar: calendar))
        #expect(LampRules.isOpen(photoDay: "2026-10-26", now: date(2026, 10, 27, 0, 0), calendar: calendar))
        #expect(!LampRules.isOpen(photoDay: "broken", now: date(2026, 10, 27), calendar: calendar))
        #expect(LampRules.deadline(photoDay: "2026-10-26", calendar: calendar) == date(2026, 10, 28, 0, 0))
    }

    // MARK: 決める(同数は固定のランダム)

    @Test func zeroLampsMeansNoPick() {
        #expect(LampRules.pickWinner(counts: [:], day: "2026-10-26") == nil)
        #expect(LampRules.pickWinner(counts: ["a": 0, "b": 0], day: "2026-10-26") == nil)
    }

    @Test func highestCountWins() {
        #expect(LampRules.pickWinner(counts: ["a": 1, "b": 5, "c": 2], day: "2026-10-26") == "b")
    }

    @Test func tiesAreBrokenTheSameWayForEveryone() {
        let counts = ["a": 3, "b": 3, "c": 3, "d": 1]
        let first = LampRules.pickWinner(counts: counts, day: "2026-10-26")
        #expect(first != nil)
        #expect(["a", "b", "c"].contains(first!))
        for _ in 0..<20 {
            // 辞書の並びが変わっても、同じ結果
            let shuffled = Dictionary(uniqueKeysWithValues: counts.shuffled())
            #expect(LampRules.pickWinner(counts: shuffled, day: "2026-10-26") == first)
        }
        // day が変われば、順番は変わりうる(day + photoRecordName から決まる)
        let scores = ["2026-10-26", "2026-10-27", "2026-10-28"].map { LampRules.tieBreakScore(day: $0, photoRecordName: "a") }
        #expect(Set(scores).count == 3)
    }

    // MARK: 365日の保持

    @Test func keptForExactly365Days() {
        #expect(LampRules.keepUntil(day: "2026-01-01", calendar: calendar) == date(2027, 1, 1, 0, 0))
        #expect(LampRules.isKept(day: "2026-01-01", now: date(2026, 12, 31, 23, 59), calendar: calendar))
        #expect(!LampRules.isKept(day: "2026-01-01", now: date(2027, 1, 1, 0, 0), calendar: calendar))
        #expect(!LampRules.isKept(day: "broken", now: date(2027, 1, 1), calendar: calendar))
    }

    @Test func daysAgoCountsCalendarDays() {
        #expect(LampRules.daysAgo(day: "2026-10-26", now: date(2026, 10, 27, 0, 5), calendar: calendar) == 1)
        #expect(LampRules.daysAgo(day: "2026-10-27", now: date(2026, 10, 27, 23, 59), calendar: calendar) == 0)
        #expect(LampRules.daysAgo(day: "2026-10-28", now: date(2026, 10, 27), calendar: calendar) == -1)
    }

    // MARK: 薄れる

    @Test func fadeStartsAt280AndEndsAtMinimumBy372() {
        #expect(LampRules.fadeOpacity(daysAgo: 0) == 1)
        #expect(LampRules.fadeOpacity(daysAgo: 280) == 1)
        #expect(LampRules.fadeOpacity(daysAgo: -3) == 1)
        #expect(abs(LampRules.fadeOpacity(daysAgo: 372) - 0.18) < 1e-9)
        #expect(abs(LampRules.fadeOpacity(daysAgo: 500) - 0.18) < 1e-9)
        // 真ん中(326日前)は、100% と 18% のちょうど真ん中
        #expect(abs(LampRules.fadeOpacity(daysAgo: 326) - 0.59) < 1e-9)
        let samples = stride(from: 270, through: 380, by: 5).map { LampRules.fadeOpacity(daysAgo: $0) }
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(LampRules.fadeSaturation(daysAgo: 280) == 1)
        #expect(LampRules.fadeSaturation(daysAgo: 372) < 1)
        #expect(LampRules.fadeSaturation(daysAgo: 365) > LampRules.fadeSaturation(daysAgo: 372))
    }

    // MARK: 触覚

    @Test func placeHapticIsSoftThenMediumAfter50ms() {
        let pulses = LampRules.placeHaptic
        #expect(pulses.count == 2)
        #expect(pulses[0].intensity == 0.45 && pulses[0].at == 0)
        #expect(pulses[1].intensity == 0.7 && pulses[1].at == 0.05)
        #expect(LampRules.cancelHaptic.count == 1)
    }

    // MARK: 匿名ID・CloudKit の準備

    @Test func userHashIsStableAnonymousAndDifferentPerUser() {
        let a = LampIdentity.userHash(source: "_abc123")
        #expect(a == LampIdentity.userHash(source: "_abc123"))
        #expect(a != LampIdentity.userHash(source: "_abc124"))
        #expect(a.count == 24)
        #expect(!a.contains("abc123"))
    }

    @Test func recordRoundTripsThroughCloudKit() throws {
        let lamp = Lamp(day: "2026-10-26", scope: "world", photoRecordName: "p1", userId: "uh", updatedAt: t0)
        let record = LampRecord.makeRecord(from: lamp)
        #expect(record.recordType == "Lamp")
        #expect(record.recordID.recordName == "lamp_uh_2026-10-26_world")
        #expect(LampRecord.lamp(from: record) == lamp)
        let zone = CKRecordZone.ID(zoneName: "group", ownerName: CKCurrentUserDefaultName)
        #expect(LampRecord.makeRecord(from: lamp, zoneID: zone).recordID.zoneID == zone)
        #expect(LampRecord.lamp(from: CKRecord(recordType: "Other")) == nil)
    }
}

// MARK: - 保存とボード

@MainActor
struct LampBoardTests {
    /// 今日の日付(古い灯は読みこみのとき捨てるので、実際の今日を使う)
    private let day = LampRules.dayKey(for: Date())

    private func defaults() -> UserDefaults {
        let name = "lamp-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func toggleSavesAndQueuesChanges() {
        let d = defaults()
        let board = LampBoard(defaults: d, userIdProvider: { "u1" })
        #expect(board.litPhoto(day: day, scope: "world") == nil)
        #expect(board.toggle(day: day, scope: "world", photoRecordName: "p1") == .placed)
        #expect(board.isLit(day: day, scope: "world"))
        #expect(board.pending.last?.kind == .save)
        #expect(board.toggle(day: day, scope: "world", photoRecordName: "p2") == .moved(from: "p1"))
        #expect(board.litPhoto(day: day, scope: "world") == "p2")
        // 同じ灯への古い変更は、新しい変更で置きかわる
        #expect(board.pending.count == 1)
        #expect(board.toggle(day: day, scope: "world", photoRecordName: "p2") == .cancelled)
        #expect(!board.isLit(day: day, scope: "world"))
        #expect(board.pending.count == 1)
        #expect(board.pending[0].kind == .delete)

        // 保存したものは、作りなおしても戻る
        _ = board.toggle(day: day, scope: "g1", photoRecordName: "x")
        let again = LampBoard(defaults: d, userIdProvider: { "u1" })
        #expect(again.litPhoto(day: day, scope: "g1") == "x")
        #expect(again.pending.count == 2)
    }

    @Test func otherUsersLampsDoNotShowAsMine() {
        let d = defaults()
        let a = LampBoard(defaults: d, userIdProvider: { "u1" })
        _ = a.toggle(day: day, scope: "world", photoRecordName: "p1")
        let b = LampBoard(defaults: d, userIdProvider: { "u2" })
        #expect(!b.isLit(day: day, scope: "world"))
    }

    @Test func oldLampsArePruned() {
        let cal = Calendar.current
        let now = Date()
        func key(_ ago: Int) -> String { LampRules.dayKey(for: cal.date(byAdding: .day, value: -ago, to: now)!) }
        let lamps = [
            Lamp(day: key(1), scope: "world", photoRecordName: "a", userId: "u", updatedAt: now),
            Lamp(day: key(LampStorage.keepDays), scope: "world", photoRecordName: "b", userId: "u", updatedAt: now),
            Lamp(day: key(LampStorage.keepDays + 1), scope: "world", photoRecordName: "c", userId: "u", updatedAt: now),
        ]
        let kept = LampStorage.pruned(lamps, now: now)
        #expect(kept.map(\.photoRecordName) == ["a", "b"])
    }
}

// MARK: - カレンダー

struct LampCalendarModelTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func twelveMonthsNewestFirst() {
        let months = LampCalendarModel.months(now: date(2026, 10, 27), calendar: calendar)
        #expect(months.count == 12)
        #expect(months.first?.id == "2026-10")
        #expect(months.last?.id == "2025-11")
        #expect(months.first?.label == "2026.10")
        #expect(months[0].days.count == 31)
        #expect(months[0].days.first?.key == "2026-10-01")
        #expect(months[0].days.last?.key == "2026-10-31")
        // 2026-10-01 は木曜(日曜はじまりで4マス空ける)
        #expect(months[0].leadingBlanks == 4)
        // 年をまたぐ
        #expect(months[10].id == "2025-12")
    }

    @Test func cellKinds() {
        let now = date(2026, 10, 27, 10)
        func kind(_ day: String, pick: Bool = false, at: Date? = nil) -> CalendarCellKind {
            LampCalendarModel.kind(day: day, now: at ?? now, hasWorldPick: pick, calendar: calendar)
        }
        #expect(kind("2026-10-27") == .today)
        #expect(kind("2026-10-28") == .future)
        #expect(kind("2026-10-20", pick: true) == .announced)
        #expect(kind("2026-10-20") == .empty)
        // 昨日:9:00 前は発表待ち、9:00 を過ぎて一枚がなければ「一枚がない日」
        #expect(kind("2026-10-26", at: date(2026, 10, 27, 8)) == .awaiting)
        #expect(kind("2026-10-26", at: date(2026, 10, 27, 10)) == .empty)
        #expect(kind("2026-10-26", pick: true, at: date(2026, 10, 27, 10)) == .announced)
        // 365日より前は、薄い枠だけ
        #expect(kind("2025-10-27") == .beyondYear)
        #expect(kind("2025-10-28", pick: true) == .announced)
    }

    @Test func worldPickShownOnlyOnDaysIShot() {
        #expect(LampCalendarModel.showsWorldPick(day: "2026-10-20", shotDays: ["2026-10-20"]))
        #expect(!LampCalendarModel.showsWorldPick(day: "2026-10-21", shotDays: ["2026-10-20"]))
    }

    @Test func groupDotsAreCappedAtThree() {
        #expect(LampCalendarModel.groupDotCount(0) == 0)
        #expect(LampCalendarModel.groupDotCount(2) == 2)
        #expect(LampCalendarModel.groupDotCount(10) == 3)
    }

    @Test(arguments: [320.0, 335.0, 362.0, 400.0])
    func cellsAlwaysFitInTheWidth(width: Double) {
        let cell = LampCalendarModel.cellSize(forWidth: CGFloat(width))
        #expect(cell.width * 7 + 6 * 6 <= CGFloat(width))
        #expect(abs(cell.height / cell.width - 4.3 / 3) < 0.05)
    }

    @Test func worldCardHeightFollowsWidth() {
        // 参考 350 × 452
        #expect(abs(350 * AnnouncedWorldCard.aspect - 452) < 0.001)
    }

    @Test func iconShapesStayInsideTheirRect() {
        let rect = CGRect(x: 0, y: 0, width: 24, height: 24)
        for path in [LampOuterShape().path(in: rect), LampInnerShape().path(in: rect)] {
            let box = path.boundingRect
            #expect(box.minX >= 5.7 && box.maxX <= 18.3)
            #expect(box.minY >= 2.5 && box.maxY <= 19.7)
        }
        // 大きさに合わせて拡大される
        let big = LampOuterShape().path(in: CGRect(x: 0, y: 0, width: 48, height: 48)).boundingRect
        #expect(abs(big.height - 2 * LampOuterShape().path(in: rect).boundingRect.height) < 0.01)
    }
}
