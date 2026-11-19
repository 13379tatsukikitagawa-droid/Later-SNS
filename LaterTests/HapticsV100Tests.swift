import Testing
import Foundation
@testable import Later_再度

@MainActor
@Suite(.serialized)
struct HapticsV100Tests {
    private func setup(_ level: AppHapticsSetting.Level) {
        AppHapticsSetting.level = level
        Haptics.recordsPlays = true
        Haptics.isMuted = false
        Haptics.resetForTesting()
    }
    private func teardown() { Haptics.recordsPlays = false; Haptics.isMuted = false; AppHapticsSetting.level = .strong; Haptics.resetForTesting() }

    @Test func ひかえめでは_さわる段が鳴らない() {
        setup(.normal)
        Haptics.play(.notch); Haptics.play(.tick); Haptics.play(.edge)
        #expect(Haptics.playedLog.isEmpty)
        Haptics.play(.pop)
        #expect(Haptics.playedLog == [.pop])
        teardown()
    }

    @Test func しっかりでは_notchが鳴る() {
        setup(.strong)
        Haptics.play(.notch)
        #expect(Haptics.playedLog == [.notch])
        teardown()
    }

    @Test func オフでは_なにも鳴らない() {
        setup(.off)
        Haptics.play(.success); Haptics.play(.notch)
        #expect(Haptics.playedLog.isEmpty)
        teardown()
    }

    @Test func 全体で40ms以内の2回目は鳴らない() {
        setup(.strong)
        Haptics.play(.pop); Haptics.play(.click)
        #expect(Haptics.playedLog == [.pop])
        teardown()
    }

    @Test func 録画中は鳴らない() {
        setup(.strong)
        Haptics.isMuted = true
        Haptics.play(.pop)
        #expect(Haptics.playedLog.isEmpty)
        teardown()
    }

    @Test func 新しい5つの波形() {
        #expect(Haptics.Tuning.beats(.notch).count == 1 && Haptics.Tuning.beats(.notch)[0].intensity == 0.22)
        #expect(Haptics.Tuning.beats(.knock).map(\.time) == [0, 0.07])
        #expect(Haptics.Tuning.beats(.sig).count == 3)
        #expect(Haptics.Tuning.gaps[.notch] == 0.055)
    }

    @Test func カウントダウンの数と音() {
        #expect(HapticCountdown.shownNumber(10) == 10 && HapticCountdown.shownNumber(0.4) == 1)
        #expect(HapticCountdown.shownNumber(10.5) == nil && HapticCountdown.shownNumber(0) == nil)
        #expect(HapticCountdown.kind(for: 4) == .tick && HapticCountdown.kind(for: 3) == .click)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let d = cal.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 8, minute: 59, second: 50))!
        let n = HapticCountdown.nearest(after: d, calendar: cal)
        #expect(n.target == .open && abs(n.seconds - 10) < 0.001)
        let e = cal.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 23, minute: 59, second: 55))!
        #expect(HapticCountdown.nearest(after: e, calendar: cal).target == .lights)
    }

    @Test func スクロール_区切りと_はやさ() {
        setup(.strong)
        let m = ScrollHapticsModel()
        m.scroll(ScrollHapticsSnap(offset: 0, maxOffset: 2000, viewport: 800), now: Date(timeIntervalSince1970: 0))
        m.report("a", y: 400, locked: false)             // 線 = 280 の 下
        m.report("a", y: 200, locked: false)             // 上へ こえた
        #expect(Haptics.playedLog == [.notch])
        Haptics.resetForTesting()
        m.report("b", y: 400, locked: true); m.report("b", y: 100, locked: true)
        #expect(Haptics.playedLog == [.knock])
        teardown()
    }
}
