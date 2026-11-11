import Foundation
import Testing
@testable import Later_再度

/// v32 まんなかの 丸 = 万能ボタン:まんなかと まわりの 決まり
struct HomeOrbRulesTests {
    typealias Input = HomeOrbRules.Input

    @Test func 招待が_いちばん() {
        let input = Input(hasInvite: true, used: 0, remaining: 3, hasUnread: true, hasGroups: true)
        #expect(HomeOrbRules.center(input) == .join)
        #expect(HomeOrbRules.pill(.join) == "JOIN")
    }

    @Test func 今日0枚なら_撮る() {
        let input = Input(used: 0, remaining: 3, hasUnread: true, hasGroups: true)
        #expect(HomeOrbRules.center(input) == .shoot)
        #expect(HomeOrbRules.sub(.shoot, input: input, name: nil, done: false) == "3 LEFT")
        #expect(HomeOrbRules.pill(.shoot) == "TAP")
    }

    @Test func 撮ったあと_新しいメッセージ() {
        let input = Input(used: 1, remaining: 2, hasUnread: true, hasGroups: true)
        #expect(HomeOrbRules.center(input) == .chat)
        #expect(HomeOrbRules.sub(.chat, input: input, name: "いつメン", done: false) == "いつメン")
        #expect(HomeOrbRules.pill(.chat) == "OPEN")
    }

    @Test func それ以外は_きのう() {
        let input = Input(used: 1, remaining: 2, hasGroups: true, openedYesterday: 1)
        let plan = HomeOrbRules.plan(input)
        #expect(plan.center == .yesterday)
        #expect(!plan.done)
        #expect(HomeOrbRules.sub(.yesterday, input: input, name: nil, done: false) == "1 OPENED")
    }

    @Test func 撮りきって_きのうも_ない_なら_また_あした() {
        let plan = HomeOrbRules.plan(Input(used: 3, remaining: 0, hasGroups: true, openedYesterday: 0))
        #expect(plan.center == .yesterday)
        #expect(plan.done)
        #expect(HomeOrbRules.sub(.yesterday, input: Input(used: 3, remaining: 0), name: nil, done: true) == "OPENS 9:00")
        #expect(!HomeOrbRules.plan(Input(used: 3, remaining: 0, openedYesterday: 2)).done)
    }

    @Test func まわりは_順に_4つ_まんなか以外() {
        // 0枚:撮る が まんなか → きのう・New group・Mondo・Friends(グループ なし)
        #expect(HomeOrbRules.plan(Input(used: 0, remaining: 3)).satellites == [.yesterday, .newGroup, .mondo, .friends])
        // 0枚・グループ あり → きのう・チャット・New group・Mondo
        #expect(HomeOrbRules.plan(Input(used: 0, remaining: 3, hasGroups: true)).satellites == [.yesterday, .chat, .newGroup, .mondo])
        // 1枚:きのう が まんなか → 撮る・現像・チャット・New group
        #expect(HomeOrbRules.plan(Input(used: 1, remaining: 2, hasGroups: true, openedYesterday: 1)).satellites == [.shoot, .develop, .chat, .newGroup])
        // 3枚:撮る は 出ない
        #expect(HomeOrbRules.plan(Input(used: 3, remaining: 0, hasGroups: false)).satellites == [.develop, .newGroup, .mondo, .friends])
        // 招待:撮る・きのう・チャット・New group
        #expect(HomeOrbRules.plan(Input(hasInvite: true, used: 0, remaining: 3, hasGroups: true)).satellites == [.shoot, .yesterday, .chat, .newGroup])
        // 新しい メッセージ:チャットは まんなか → まわりに 出さない
        #expect(HomeOrbRules.plan(Input(used: 2, remaining: 1, hasUnread: true, hasGroups: true)).satellites == [.shoot, .develop, .yesterday, .newGroup])
    }

    @Test func まだ_ひらかない_ものと_点() {
        #expect(HomeOrbRules.isLocked(.yesterday, used: 0))
        #expect(HomeOrbRules.isLocked(.mondo, used: 0))
        #expect(!HomeOrbRules.isLocked(.yesterday, used: 1))
        #expect(!HomeOrbRules.isLocked(.friends, used: 0))
        #expect(HomeOrbRules.hasDot(.chat, input: Input(hasUnread: true, hasGroups: true)))
        #expect(!HomeOrbRules.hasDot(.chat, input: Input(hasGroups: true)))
        #expect(HomeOrbRules.hasDot(.newGroup, input: Input(hasGroups: false)))
        #expect(!HomeOrbRules.hasDot(.newGroup, input: Input(hasGroups: true)))
    }

    @Test func フィルムの弧と_文字の輪() {
        #expect((0..<3).map { HomeOrbRules.arcIsRemaining($0, used: 0) } == [true, true, true])
        #expect((0..<3).map { HomeOrbRules.arcIsRemaining($0, used: 1) } == [false, true, true])
        #expect((0..<3).map { HomeOrbRules.arcIsRemaining($0, used: 3) } == [false, false, false])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 10))!
        #expect(HomeOrbRules.ringText(now: date, calendar: calendar).hasPrefix("LATER — TODAY — YESTERDAY — 3 SHOTS A DAY — 11.11 — LATER"))
    }

    @Test func ラベルは_英語() {
        #expect(HomeOrbAction.shoot.title == "Shoot")
        #expect(HomeOrbAction.yesterday.title == "Yesterday")
        #expect(HomeOrbAction.newGroup.title == "New group")
        #expect(HomeOrbAction.newGroup.label == "NEW GROUP")
    }
}
