import CoreGraphics
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

    /// v61 §8:四すみは 状況で 入れかえない。常に 左上 Yesterday・右上 Trip・左下 Mondo・右下 Friends の 固定 4つ。
    @Test func まわりは_四つ固定_状況で_入れかえない() {
        #expect(HomeOrbRules.plan(Input(used: 0, remaining: 3)).satellites == [.yesterday, .trip, .mondo, .friends])
        #expect(HomeOrbRules.plan(Input(used: 0, remaining: 3, hasGroups: true)).satellites == [.yesterday, .trip, .mondo, .friends])
        #expect(HomeOrbRules.plan(Input(used: 1, remaining: 2, hasGroups: true, openedYesterday: 1)).satellites == [.yesterday, .trip, .mondo, .friends])
        #expect(HomeOrbRules.plan(Input(used: 3, remaining: 0, hasGroups: false)).satellites == [.yesterday, .trip, .mondo, .friends])
        #expect(HomeOrbRules.plan(Input(hasInvite: true, used: 0, remaining: 3, hasGroups: true)).satellites == [.yesterday, .trip, .mondo, .friends])
        #expect(HomeOrbRules.plan(Input(used: 2, remaining: 1, hasUnread: true, hasGroups: true)).satellites == [.yesterday, .trip, .mondo, .friends])
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

    @Test func 文字の輪は_まわりの_下で_消える() {
        let holes = (0..<4).map { HomeOrbRules.satelliteHole(.newGroup, index: $0) }
        // まわりの 4つの ボタン自身の 場所では 消える
        for o in HomeOrbRules.satelliteOffsets() {
            #expect(HomeRingText.visibility(at: CGPoint(x: o.width, y: o.height), holes: holes) == 0)
        }
        // まんなかの 真上・真下(x=0)は どの 穴にも 入らず 見える
        let r = hypot(Double(HomeOrbRules.satelliteOffsets()[0].width), Double(HomeOrbRules.satelliteOffsets()[0].height))
        #expect(HomeRingText.visibility(at: CGPoint(x: 0, y: -r), holes: holes) == 1)
        #expect(HomeRingText.visibility(at: CGPoint(x: 0, y: r), holes: holes) == 1)
        // 長い 字ほど 広い
        #expect(HomeOrbRules.satelliteHole(.newGroup, index: 0).width > HomeOrbRules.satelliteHole(.chat, index: 0).width)
    }

    /// v61 §15:四すみは「端からの 距離」。幅(375・390・402)が 変わっても、丸の 中心は 端から 62pt の まま。
    @Test func 四すみは_幅が変わっても_端から62pt() {
        for w: CGFloat in [375, 390, 402] {
            let offsets = HomeOrbRules.satelliteOffsets(width: w)
            // 左上・左下(index 0・2):中心からの 距離は w/2 - 62 → 端からは ちょうど 62pt
            #expect(abs(Double(w / 2 + offsets[0].width) - 62) < 0.01)
            #expect(abs(Double(w / 2 + offsets[2].width) - 62) < 0.01)
            // 右上・右下(index 1・3):同じく 端(右)から 62pt
            #expect(abs(Double(w / 2 - offsets[1].width) - 62) < 0.01)
            #expect(abs(Double(w / 2 - offsets[3].width) - 62) < 0.01)
            // y(縦)は 幅に よらず 固定
            #expect(offsets[0].height == -232)
            #expect(offsets[2].height == 218)
        }
    }
}
