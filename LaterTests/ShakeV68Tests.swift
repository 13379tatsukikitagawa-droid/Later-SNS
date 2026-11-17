import Testing
import Foundation
@testable import Later_再度

/// P12-D(v68):Shake の 純粋な 決まり
struct ShakeV68Tests {
    private func verdict(_ id: String) -> ShakeV68Rules.Verdict {
        ShakeV68Rules.verdict(for: id, me: "me", friends: ["f"], blocked: ["b"], declined: ["d"], cancelled: ["c"])
    }

    @Test func ふった判定は二回の山が近いとき成立() {
        var d = ShakeDetector()
        let a = d.feed(time: 0.00, g: 2.5)
        let b = d.feed(time: 0.10, g: 1.0)
        let c = d.feed(time: 0.40, g: 2.6)
        #expect(a == false)
        #expect(b == false)
        #expect(c == true)
    }

    @Test func ふった判定は間があくと成立しない() {
        var d = ShakeDetector()
        _ = d.feed(time: 0.0, g: 2.5)
        _ = d.feed(time: 0.1, g: 1.0)
        let late = d.feed(time: 0.9, g: 2.6)
        #expect(late == false)
    }

    @Test func 山が下がらない間は一回と数える() {
        var d = ShakeDetector()
        _ = d.feed(time: 0.00, g: 2.5)
        let x = d.feed(time: 0.05, g: 2.4)
        let y = d.feed(time: 0.10, g: 2.3)
        #expect(x == false)
        #expect(y == false)
    }

    @Test func ペアは受けとった側の自分の時計で近いとき() {
        let mine = Date(timeIntervalSince1970: 1000)
        #expect(ShakeV68Rules.isPair(myShake: mine, receivedAt: mine.addingTimeInterval(1.9)))
        #expect(ShakeV68Rules.isPair(myShake: mine, receivedAt: mine.addingTimeInterval(-1.9)))
        #expect(!ShakeV68Rules.isPair(myShake: mine, receivedAt: mine.addingTimeInterval(2.1)))
    }

    @Test func 招待するのは合言葉が小さい方だけ() {
        #expect(ShakeV68Rules.shouldInvite(myNonce: "0a", theirNonce: "0b"))
        #expect(!ShakeV68Rules.shouldInvite(myNonce: "0b", theirNonce: "0a"))
    }

    @Test func ふれる回数に上限がある() {
        let now = Date(timeIntervalSince1970: 10_000)
        let h = (0..<20).map { now.addingTimeInterval(-Double($0) * 10) }
        #expect(!ShakeV68Rules.canShake(history: h, now: now))
        #expect(ShakeV68Rules.canShake(history: Array(h.dropFirst()), now: now))
        #expect(ShakeV68Rules.canShake(history: h.map { $0.addingTimeInterval(-700) }, now: now))
    }

    @Test func ブロックと断った人と取り消した人は出さない() {
        #expect(verdict("b") == .hidden)
        #expect(verdict("d") == .hidden)
        #expect(verdict("c") == .hidden)
        #expect(verdict("me") == .hidden)
        #expect(verdict("f") == .alreadyFriend)
        #expect(verdict("x") == .show)
    }

    @Test func 重なった申請だけ自動で成立() {
        let r = ShakeV68Rules.crossed(outgoing: ["a", "b", "c"], incomingFrom: ["b", "c", "z", "b"], excluded: ["c"])
        #expect(r == ["b"])
    }
}
