import Testing
@testable import Later_再度

@MainActor
struct IntroStoryV99Tests {
    @Test func 場面は4つずつで_バイブは3_6秒の中() {
        for k in IntroKind.allCases {
            #expect(k.scenes.count == 4)
            for s in k.scenes {
                #expect(!s.line.isEmpty && !s.label.isEmpty)
                #expect(s.haptics.allSatisfy { $0.0 >= 0 && $0.0 <= 3.6 })
                #expect(s.haptics.map(\.0) == s.haptics.map(\.0).sorted())
            }
        }
    }

    @Test func 見た記録は出した時点でtrue_リセットでもどる() {
        IntroStore.resetAll()
        #expect(IntroKind.allCases.allSatisfy { !IntroStore.seen($0) })
        IntroStore.markSeen(.trip)
        #expect(IntroStore.seen(.trip) && !IntroStore.seen(.friends))
        #expect(IntroKind.trip.seenKey == "introSeen.trip")
        IntroStore.resetAll()
        #expect(!IntroStore.seen(.trip))
    }

    @Test func 動きの式() {
        #expect(IntroMath.ease(0, 0.5) == 0 && IntroMath.ease(2, 0.5) == 1)
        #expect(IntroMath.pop(0.1, 0.2) == 0 && abs(IntroMath.pop(1, 0.2) - 1) < 1e-9)
    }
}
