import SwiftUI
import Testing
@testable import Later_再度

@MainActor
struct LaunchAnimationTests {
    static let tokyo = HomeStateTests.tokyo
    static func date(_ d: Int, _ h: Int, _ m: Int) -> Date { HomeStateTests.date(d, h, m) }

    // MARK: - 3つの起動の選び方

    @Test func chooseKind() {
        let todayKey = DailyWindow.key(for: Self.date(0, 9, 30), calendar: Self.tokyo)
        let yesterdayKey = DailyWindow.key(for: Self.date(-1, 12, 0), calendar: Self.tokyo)
        // 夜は night(通知・記録に関係なく)
        #expect(LaunchCoordinator.kind(now: Self.date(0, 8, 59), lastMorningKey: nil, fromNotification: false, calendar: Self.tokyo) == .night)
        #expect(LaunchCoordinator.kind(now: Self.date(1, 0, 0), lastMorningKey: todayKey, fromNotification: true, calendar: Self.tokyo) == .night)
        // 昼・この窓でまだ → morning / すでに出した → normal
        #expect(LaunchCoordinator.kind(now: Self.date(0, 9, 0), lastMorningKey: yesterdayKey, fromNotification: false, calendar: Self.tokyo) == .morning)
        #expect(LaunchCoordinator.kind(now: Self.date(0, 9, 0), lastMorningKey: nil, fromNotification: false, calendar: Self.tokyo) == .morning)
        #expect(LaunchCoordinator.kind(now: Self.date(0, 18, 0), lastMorningKey: todayKey, fromNotification: false, calendar: Self.tokyo) == .normal)
        // 通知から開いたら normal
        #expect(LaunchCoordinator.kind(now: Self.date(0, 10, 0), lastMorningKey: yesterdayKey, fromNotification: true, calendar: Self.tokyo) == .normal)
        // 23:59 に出して、翌日 9:00 になったら、また morning
        #expect(LaunchCoordinator.kind(now: Self.date(1, 9, 0), lastMorningKey: todayKey, fromNotification: false, calendar: Self.tokyo) == .morning)
    }

    @Test func morningIsSavedAtStart() throws {
        let defaults = try #require(UserDefaults(suiteName: "LaunchAnimationTests"))
        defaults.removePersistentDomain(forName: "LaunchAnimationTests")
        LaunchCoordinator.hasPlayedInProcess = false
        LaunchCoordinator.launchedFromNotification = false
        let now = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        #expect(LaunchCoordinator.beginColdLaunchIfNeeded(now: now, defaults: defaults) == .morning)
        #expect(defaults.string(forKey: LaunchCoordinator.lastMorningWindowKey) == DailyWindow.key(for: now))
        // 同じプロセスの2回目(ウォーム起動)はなし
        #expect(LaunchCoordinator.beginColdLaunchIfNeeded(now: now, defaults: defaults) == nil)
        // 同じ窓の次のコールドスタートは normal
        LaunchCoordinator.hasPlayedInProcess = false
        #expect(LaunchCoordinator.beginColdLaunchIfNeeded(now: now.addingTimeInterval(3600), defaults: defaults) == .normal)
    }

    // MARK: - 時間 t の関数

    @Test(arguments: LaunchKind.allCases)
    func frameEnds(_ kind: LaunchKind) {
        let s = LaunchSpec.of(kind)
        let start = LaunchFrame.at(0, kind: kind)
        #expect(start.headerOpacity == 0)
        #expect(start.cardOpacity == 0)
        #expect(start.moonOpacity == 0)
        #expect(start.countFraction == 0)
        #expect(LaunchFrame.at(s.total, kind: kind) == .finished)
        // 最初はあなたの光も世界の光も見えない
        #expect(start.youOpacity == 0 && start.sweep == 0)
        // 球(ガラス)→ あなたの光(ひとりで)→ 波紋とひろがり → 文字。normal では月が最後
        if kind == .normal {
            let alone = LaunchFrame.at(440, kind: kind)
            #expect(alone.glassOpacity == 1 && alone.youOpacity > 0.9)
            #expect(alone.sweep == 0 && alone.pulse == 0)
            let f = LaunchFrame.at(700, kind: kind)
            #expect(f.pulse > 0 && f.pulse < 1 && f.sweep > 0)
            #expect(f.headOpacity == 0)
            #expect(f.moonOpacity == 0)
        }
        // 波紋とひろがりは同時に始まり、触れるのはひろがりが終わるとき
        #expect(s.pulse.0 == s.sweep.0)
        #expect(s.interactiveAt == s.sweep.1)
    }

    @Test func revealSpreadsFromMyLight() {
        // ひろがりの途中:近い点は灯り、遠い点はまだ
        #expect(LaunchFrame.reveal(sweep: 0.3, distance: 0.05) == 1)
        #expect(LaunchFrame.reveal(sweep: 0.3, distance: 0.9) == 0)
        // 終わったら、反対側(約1)の点も灯っている
        #expect(LaunchFrame.reveal(sweep: 1, distance: 1.0) == 1)
        // ぽっ、と灯る:途中でふくらんで、最後は1倍
        #expect(LaunchFrame.revealScale(0.5) > 1)
        #expect(abs(LaunchFrame.revealScale(1) - 1) < 1e-9)
        // 数字は0から増える
        #expect(LaunchFrame.at(450, kind: .normal).countFraction == 0)
        #expect(LaunchFrame.at(800, kind: .normal).countFraction > 0)
    }

    @Test func nightMoonHasNoGlow() {
        #expect(LaunchFrame.at(1500, kind: .night).moonGlowOpacity == 0)
        #expect((LaunchFrame.at(1000, kind: .morning).moonGlowOpacity ?? 0) > 0)
    }

    @Test func curves() {
        #expect(LaunchCurve.seg(50, (100, 200)) == 0)
        #expect(LaunchCurve.seg(150, (100, 200)) == 0.5)
        #expect(LaunchCurve.seg(250, (100, 200)) == 1)
        #expect(abs(LaunchCurve.e1(0.5) - 0.946) < 0.005)  // 手計算: x(0.725)=0.5 → y=0.946
        #expect(LaunchCurve.e2(0) == 0 && LaunchCurve.e2(1) == 1)
        // 単調に増える
        var last = 0.0
        for i in 1...100 {
            let v = LaunchCurve.e1(Double(i) / 100)
            #expect(v >= last - 1e-9)
            last = v
        }
    }

    @Test func skipReachesEndIn200ms() {
        let start = Date()
        var clock = LaunchClock(kind: .morning, start: start, speed: 1)
        let tapAt = start.addingTimeInterval(0.5)
        clock.skip = (tapAt, clock.t(at: tapAt))
        #expect(abs(clock.t(at: tapAt) - 500) < 1)
        #expect(clock.isFinished(at: tapAt.addingTimeInterval(0.2)))
        #expect(!clock.isFinished(at: tapAt.addingTimeInterval(0.1)))
    }

    @Test func lowPowerIsTwiceAsFast() {
        let start = Date()
        let clock = LaunchClock(kind: .normal, start: start, speed: 2)
        #expect(clock.isFinished(at: start.addingTimeInterval(0.86)))
        #expect(!clock.isFinished(at: start.addingTimeInterval(0.8)))
    }

    // MARK: - 時刻を指定した書き出し(LATER_SNAPSHOT_DIR がある時だけ)

    @Test(arguments: LaunchKind.allCases)
    func exportFrames(_ kind: LaunchKind) throws {
        guard let dir = HomeSnapshotTests.outputDirectory else { return }
        let times = LaunchSpec.debugTimes(kind)
        let shot = Self.date(0, 9, 8)
        let state: HomeState = kind == .night ? .night : .dawn
        let content: HomeDevelopCard.Content = kind == .night
            ? .developing(capturedAt: shot.addingTimeInterval(-86400), isNight: true)
            : .developed(capturedAt: shot.addingTimeInterval(-50000))
        let now = kind == .night ? Self.date(0, 6, 40) : Self.date(0, 9, 6)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for t in times {
            let frame = LaunchFrame.at(t, kind: kind)
            let image = try #require(HomeSnapshotTests.renderHome(state: state, content: content, now: now, light: .count(128), launch: frame))
            try #require(image.pngData()).write(to: dir.appendingPathComponent("launch_\(kind.rawValue)_\(Int(t)).png"))
        }
    }
}
