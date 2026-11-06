import Testing
import Foundation
import QuartzCore
@testable import Later_再度

/// 撮影フロー(タグ → 撮影 → 撮影後)のロジック
@MainActor
struct CaptureFlowLogicTests {
    // MARK: HoldShutter

    @Test func holdFiresOnceAtOnePointFiveSeconds() {
        var clock: CFTimeInterval = 100
        let hold = HoldShutter(now: { clock })
        var fired = 0
        var stages: [Int] = []
        hold.onFire = { fired += 1 }
        hold.onStage = { stages.append($0) }
        hold.begin()
        #expect(hold.isHolding)
        #expect(hold.tick(elapsed: 0.75) == false)
        #expect(abs(hold.progress - 0.5) < 0.0001)
        #expect(hold.stage == 1)
        hold.tick(elapsed: 1.2)
        #expect(hold.stage == 2)
        #expect(hold.tick(elapsed: 1.5) == true)
        #expect(fired == 1)
        #expect(stages == [1, 2])
        // 指を離さずにいても、もう一度は始めない
        hold.begin()
        #expect(!hold.isHolding)
        // 離すと、フラグが戻って、また始められる
        clock = 200
        hold.end()
        #expect(hold.progress == 0)
        hold.begin()
        #expect(hold.isHolding)
        hold.end()
    }

    @Test func releasingEarlyCancelsAndDoesNotFire() {
        let hold = HoldShutter(now: { 0 })
        var fired = false
        var cancelled = false
        hold.onFire = { fired = true }
        hold.onCancel = { cancelled = true }
        hold.begin()
        hold.tick(elapsed: 0.9)
        hold.end()
        #expect(!fired)
        #expect(cancelled)
        #expect(hold.progress == 0)
        #expect(hold.stage == 0)
    }

    @Test func refusedPressDoesNotStartAndReportsOncePerPress() {
        let hold = HoldShutter(now: { 0 })
        var refused = 0
        hold.canStart = { false }
        hold.onRefused = { refused += 1 }
        hold.begin()
        hold.begin()   // 指が動いても、1回の押しでは1回だけ
        #expect(!hold.isHolding)
        #expect(refused == 1)
        hold.end()
        hold.begin()
        #expect(refused == 2)
    }

    @Test func hintTextFollowsStages() {
        #expect(HoldShutter.hint(for: 0) == "ながおしで、撮る")
        #expect(HoldShutter.hint(for: 0.2) == "そのまま…")
        #expect(HoldShutter.hint(for: 0.5) == "もうすこし")
        #expect(HoldShutter.hint(for: 0.8) == "もうすぐ")
    }

    @Test func heartbeatSpeedsUpFromOnePointTwoToThreePointEight() {
        // 位相の傾き(=周波数×2π)が、はじめ 1.2回/秒、おわり 3.8回/秒
        let dt = 0.0001
        let start = (HoldShutter.heartbeatPhase(elapsed: dt) - HoldShutter.heartbeatPhase(elapsed: 0)) / dt / (2 * .pi)
        let end = (HoldShutter.heartbeatPhase(elapsed: 1.5) - HoldShutter.heartbeatPhase(elapsed: 1.5 - dt)) / dt / (2 * .pi)
        #expect(abs(start - 1.2) < 0.01)
        #expect(abs(end - 3.8) < 0.01)
    }

    // MARK: TagRules

    @Test func tagRulesCleanAndLimit() {
        #expect(TagRules.maxCount == 2)
        #expect(TagRules.clean("  #ねむい ") == "ねむい")
        #expect(TagRules.clean("＃＃ 空") == "空")
        #expect(TagRules.clean("a#b") == "a#b")
        #expect(TagRules.clean(String(repeating: "あ", count: 20)).count == 16)
        #expect(!TagRules.canAdd("", to: []))
        #expect(!TagRules.canAdd("空", to: ["空"]))
        #expect(TagRules.canAdd("空", to: ["朝"]))
        #expect(!TagRules.canAdd("空", to: ["朝", "電車"]))
    }

    @Test func dictionaryIsMostlyEmotions() {
        let emotions = Double(TagDictionary.emotions.count)
        let all = Double(TagDictionary.all.count)
        #expect(emotions / all > 0.7 && emotions / all < 0.8)
        #expect(Set(TagDictionary.all).count == TagDictionary.all.count)
        #expect(TagDictionary.display("朝") == "#朝")
        #expect(TagDictionary.display("ねむい") == "ねむい")
    }

    // MARK: テープの色(FNV-1a)

    @Test func fnv1aIsStable() {
        // FNV-1a 64bit の既知の値
        #expect(FNV1a.hash("") == 0xcbf2_9ce4_8422_2325)
        #expect(FNV1a.hash("a") == 0xaf63_dc4c_8601_ec8c)
        #expect(FNV1a.hash("ねむい") == FNV1a.hash("ねむい"))
    }

    @Test func tapeColorsFollowTheTableAndCustomWordsAreStable() {
        #expect(TapeStyle.color(for: "がんばった") == .t4)
        #expect(TapeStyle.color(for: "わくわく") == .t2)
        #expect(TapeStyle.color(for: "ねむい") == .t3)
        #expect(TapeStyle.color(for: "ほっとした") == .t5)
        #expect(TapeStyle.color(for: "しあわせ") == .t6)
        #expect(TapeStyle.color(for: "だるい") == .t1)
        let custom = "部活のあと"
        #expect(TapeStyle.color(for: custom) == TapeColor.allCases[Int(FNV1a.hash(custom) % 6)])
        for word in TagDictionary.all {
            let tilt = TapeStyle.tilt(for: word)
            #expect(tilt >= -1.4 && tilt <= 1.2)
        }
    }

    // MARK: 流れ(MarqueeRow)

    @Test func marqueeSplitsIntoThreeRowsAndLoopsSeamlessly() {
        let rows = MarqueeMath.rows(TagDictionary.all, rowCount: 3)
        #expect(rows.count == 3)
        #expect(rows.flatMap { $0 }.sorted() == TagDictionary.all.sorted())
        #expect(rows.map(\.count).max()! - rows.map(\.count).min()! <= 1)
        // 1周でもとの位置にもどる(つなぎ目が見えない)
        let a = MarqueeMath.offset(time: 10, secondsPerLoop: 46, phase: 0.3, setWidth: 700, reversed: false)
        let b = MarqueeMath.offset(time: 56, secondsPerLoop: 46, phase: 0.3, setWidth: 700, reversed: false)
        #expect(abs(a - b) < 0.001)
        // 左へ流れる段は、時間とともに x が小さくなる。右へは大きくなる
        let l1 = MarqueeMath.offset(time: 1, secondsPerLoop: 46, phase: 0, setWidth: 700, reversed: false)
        let l2 = MarqueeMath.offset(time: 2, secondsPerLoop: 46, phase: 0, setWidth: 700, reversed: false)
        #expect(l2 < l1)
        let r1 = MarqueeMath.offset(time: 1, secondsPerLoop: 38, phase: 0, setWidth: 700, reversed: true)
        let r2 = MarqueeMath.offset(time: 2, secondsPerLoop: 38, phase: 0, setWidth: 700, reversed: true)
        #expect(r2 > r1)
        #expect(r1 <= 0 && r1 >= -700)
    }

    // MARK: のこり

    @Test func leftComesFromShotsToday() {
        #expect(FilmRoll.shotsPerDay == 3)
        #expect(FilmRoll.shotsRemaining(shotsToday: 0) == 3)
        #expect(FilmRoll.shotsRemaining(shotsToday: 2) == 1)
        #expect(FilmRoll.shotsRemaining(shotsToday: 5) == 0)
    }

    // MARK: 曲線

    @Test func easingCurvesStartAndEndAtTheEnds() {
        for curve in [CaptureEase.out, CaptureEase.io, CaptureEase.eject, CaptureEase.fly] {
            #expect(curve(0) == 0)
            #expect(curve(1) == 1)
            #expect(curve(0.5) > 0 && curve(0.5) < 1.01)
        }
        #expect(CaptureEase.out(0.3) > 0.5)        // はやく出て、ゆっくり止まる
        #expect(abs(CaptureEase.spring(3) - 1) < 0.001)
        #expect(CaptureEase.spring(0.25) > 1)     // 少し行きすぎる
    }

    @Test func layoutMatchesTheReferenceSize() {
        let layout = CaptureLayout(size: CGSize(width: 390, height: 844), safeTop: 59, safeBottom: 34)
        #expect(layout.shutterCenter == CGPoint(x: 195, y: 744))
        #expect(layout.finder.minX == 12)
        #expect(layout.finder.minY == 99)
        #expect(layout.finder.width == 366)
        #expect(abs(layout.finder.height - 559) < 0.5)
    }
}
