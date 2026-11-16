#if DEBUG
import SwiftUI
import UIKit

/// DEBUG ビルドだけ。モックの デモボタン(`#ctl`)と 同じ 名前の 状態を 切りかえる。
/// 値は UserDefaults(`debug.*`)に 置く。画面は 作るときに ここを 読む(P01 以降で 順に つなぐ)。
/// Firebase・認証・課金・CloudKit には 書きこまない。
@MainActor @Observable
final class DebugState {
    static let shared = DebugState()
    private let d = UserDefaults.standard

    enum Key {
        static let friends = "debug.friends"          // 0 / 3
        static let requests = "debug.requests"        // Bool
        static let firstDay = "debug.firstDay"        // Bool
        static let trip = "debug.trip"                // Bool
        static let invite = "debug.invite"            // Bool
        static let nextMorning = "debug.nextMorning"  // Bool(翌朝 9:00)
        static let sample = "debug.sampleData"        // Bool
    }

    var friends: Int { didSet { d.set(friends, forKey: Key.friends) } }
    var requests: Bool { didSet { d.set(requests, forKey: Key.requests) } }
    var firstDay: Bool { didSet { d.set(firstDay, forKey: Key.firstDay) } }
    var trip: Bool { didSet { d.set(trip, forKey: Key.trip) } }
    var invite: Bool { didSet { d.set(invite, forKey: Key.invite) } }
    var nextMorning: Bool { didSet { d.set(nextMorning, forKey: Key.nextMorning) } }
    var sampleData: Bool { didSet { d.set(sampleData, forKey: Key.sample) } }
    /// 今日 撮った 枚数(0〜3)。`FilmCounter` に 反映
    private(set) var shots: Int

    private init() {
        friends = d.integer(forKey: Key.friends)
        requests = d.bool(forKey: Key.requests)
        firstDay = d.bool(forKey: Key.firstDay)
        trip = d.bool(forKey: Key.trip)
        invite = d.bool(forKey: Key.invite)
        nextMorning = d.bool(forKey: Key.nextMorning)
        sampleData = d.bool(forKey: Key.sample)
        shots = FilmCounter.shared.used
    }

    func setShots(_ n: Int) {
        shots = max(0, min(3, n))
        FilmCounter.shared.debugReplace(used: shots)
    }

    /// 昼 ⇄ 夜(`ThemeClock` の 上書き。反映は 次の `refresh`)
    func setTheme(_ o: ThemeOverride) {
        d.set(o.rawValue, forKey: ThemeClock.overrideKey)
        NotificationCenter.default.post(name: UIApplication.significantTimeChangeNotification, object: nil)
    }
    var theme: ThemeOverride { ThemeOverride(rawValue: d.string(forKey: ThemeClock.overrideKey) ?? "") ?? .automatic }

    /// オープニングを もう一度
    func replayOpening() {
        DebugRouter.playOpening()
    }

    /// はじめての 設定を もう一度(アプリを 作りなおす まで 反映されない 場合は 再起動)
    func replayOnboarding() {
        d.removeObject(forKey: OnboardingStorage.stepKey)
        d.set(false, forKey: "isSetupCompleted")
        d.set(false, forKey: OnboardingStorage.completedKey)
    }

    /// 設定の ある 画面から はじめる(intro / in / mail / sent / name / tag / fr / nt / go)。見本を 撮る ときに 使う
    func jumpToOnboarding(_ step: String) {
        d.set(step, forKey: "debugOnbStep")
        replayOnboarding()
    }

    /// ぜんぶ 最初から(debug.* と 初回設定の 旗。サインインは そのまま)
    func resetAll() {
        for k in [Key.friends, Key.requests, Key.firstDay, Key.trip, Key.invite, Key.nextMorning, Key.sample, ThemeClock.overrideKey] {
            d.removeObject(forKey: k)
        }
        friends = 0; requests = false; firstDay = false; trip = false; invite = false; nextMorning = false; sampleData = false
        setShots(0)
        replayOnboarding()
    }
}
#endif
