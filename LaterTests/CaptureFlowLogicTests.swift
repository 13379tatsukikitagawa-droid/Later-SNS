import Testing
import Foundation
import QuartzCore
@testable import Later_再度

/// 撮影フロー(タグ → 撮影 → 撮影後)のロジック
@MainActor
struct CaptureFlowLogicTests {

    // MARK: TagRules

    @Test func tagRulesCleanAndLimit() {
        #expect(TagRules.maxCount == 3)
        #expect(TagRules.clean("  #ねむい ") == "ねむい")
        #expect(TagRules.clean("＃＃ 空") == "空")
        #expect(TagRules.clean("a#b") == "a#b")
        #expect(TagRules.clean(String(repeating: "あ", count: 20)).count == 16)
        #expect(!TagRules.canAdd("", to: []))
        #expect(!TagRules.canAdd("空", to: ["空"]))
        #expect(TagRules.canAdd("空", to: ["朝"]))
        #expect(TagRules.canAdd("空", to: ["朝", "電車"]))
        #expect(!TagRules.canAdd("空", to: ["朝", "電車", "夕方"]))
    }

    @Test func dictionaryIsMostlyEmotions() {
        let emotions = Double(TagDictionary.emotions.count)
        let all = Double(TagDictionary.all.count)
        #expect(emotions / all > 0.7 && emotions / all < 0.8)
        #expect(Set(TagDictionary.all).count == TagDictionary.all.count)
        #expect(TagDictionary.display("朝") == "#朝")
        #expect(TagDictionary.display("わくわく") == "わくわく")
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

    /// v21:見本の 390×844 のとき、窓は 左右16・上112・高さ500、シャッターの中心は 728(上端 676 + 52)
    @Test func layoutMatchesTheReferenceSize() {
        let layout = CaptureLayout(size: CGSize(width: 390, height: 844), safeTop: 47, safeBottom: 34)
        #expect(layout.shutterCenter == CGPoint(x: 195, y: 728))
        #expect(layout.finder == CGRect(x: 16, y: 112, width: 358, height: 500))
        // 小さい画面(SE):上のバーと窓は重ならない
        let se = CaptureLayout(size: CGSize(width: 375, height: 667), safeTop: 20, safeBottom: 0)
        #expect(se.finder.minY >= se.topBarCenterY + 23)
        #expect(se.finder.maxY < se.shutterCenter.y - 52)
    }
}
