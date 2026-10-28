import Foundation
import Testing
@testable import Later_再度

/// 撮影前タグの「気持ちのヒント」:8割が感情・毎回ちがう
struct EmotionHintTests {
    /// 種を固定できる乱数(テスト用)
    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    typealias C = EmotionHintCatalog

    @Test func 十個のうち感情は八個_四つのグループが毎回入る() {
        var rng = SeededRandom(state: 42)
        for i in 0..<1000 {
            let set = EmotionHintSet.make(history: [], ownTags: [], hour: [10, 14, 21][i % 3], using: &rng)
            #expect(set.river.count == 10)
            #expect(set.river.filter(C.isEmotion).count == 8)
            for group in [C.Group.bright, .calm, .lonely, .restless] {
                #expect(set.river.contains { (C.emotions[group] ?? []).contains($0) })
            }
            // うすい例:5つ(感情4+ふだん1)・先頭は感情・川①と重ならない
            #expect(set.examples.count == 5)
            #expect(set.examples.filter(C.isEmotion).count == 4)
            #expect(C.isEmotion(set.examples[0]))
            #expect(Set(set.examples).isDisjoint(with: set.river))
            #expect(Set(set.river).count == 10)
        }
    }

    @Test func 直近三回と川②の言葉は出ない() {
        var rng = SeededRandom(state: 7)
        var history: [[String]] = []
        let own = ["うれしい", "雨の日", "散歩"]
        for _ in 0..<200 {
            let set = EmotionHintSet.make(history: history, ownTags: own, hour: 14, using: &rng)
            let shown = Set(history.flatMap { $0 })
            #expect(Set(set.river + set.examples).isDisjoint(with: shown))
            #expect(Set(set.river + set.examples).isDisjoint(with: own))
            history.insert(set.river + set.examples, at: 0)
            history = Array(history.prefix(EmotionHintHistory.rounds))
        }
    }

    @Test func 言葉が足りなくても空にならない() {
        var rng = SeededRandom(state: 1)
        // 辞書のほぼすべてを除外しても、古い回からゆるめて10個そろう
        let everything = C.allEmotions + C.everyday
        let set = EmotionHintSet.make(history: [everything, everything, everything], ownTags: [], hour: 9, using: &rng)
        #expect(set.river.count == 10)
        #expect(!set.examples.isEmpty)
        // 自分のタグが辞書のすべてでも、空にならない
        let all = EmotionHintSet.make(history: [], ownTags: everything, hour: 9, using: &rng)
        #expect(!all.river.isEmpty && !all.examples.isEmpty)
    }

    @Test func 辞書の決まり() {
        for word in C.allEmotions + C.everyday {
            #expect(word.count <= ShootTagRules.maxLength)
            #expect(!word.contains("#") && word.rangeOfCharacter(from: .decimalDigits) == nil)
            #expect(ShootTagRules.normalize(word) == word)
        }
        // さびしい・ざわつく系も、明るい系と同じ数
        #expect(C.emotions[.lonely]?.count == C.emotions[.bright]?.count)
        #expect(C.emotions[.restless]?.count == C.emotions[.bright]?.count)
    }

    @Test func 履歴は三回ぶんだけ端末に残る() throws {
        let defaults = try #require(UserDefaults(suiteName: "EmotionHintTests"))
        defaults.removePersistentDomain(forName: "EmotionHintTests")
        for _ in 0..<5 { _ = EmotionHintHistory.next(ownTags: [], defaults: defaults) }
        #expect(EmotionHintHistory.load(defaults: defaults).count == 3)
        #expect(EmotionHintHistory.load(defaults: defaults).allSatisfy { $0.count == 15 })
    }

    @Test func 入力中の候補は感情が先() {
        let candidates = BundledTagSuggestionProvider().candidates(matching: "し")
        #expect(candidates.first.map(C.isEmotion) == true)
    }
}
