import Foundation
import ActivityKit
import WidgetKit

// P40 B:ライブ アクティビティの 始め方 ・ 更新 ・ 終わり方(PROMPT_v97.md 1章)。
// 23:00 まで 3枚 撮って いない 人に「フィルム」→ 23:50 に「ラストコール」→ 24:00 か 3枚 撮った 時に 終わる。
// 8:30〜9:00 は「朝の 部」(きのう 1枚 以上 撮った 人 だけ)。夜 / 朝は 設定で 別々に オフに できる。
// アプリが 前面の 時は ここから 始める。ほかの 時は サーバーの push-to-start(トークンは 控えて おく ・ 送る 側は server/live-activity)。

@MainActor
enum LattagLive {
    static let nightKey = "notify.liveNight"
    static let morningKey = "notify.liveMorning"
    static let startTokenKey = "live.pushToStartToken"
    static let pushTokenKey = "live.pushToken"

    static var nightOn: Bool { UserDefaults.standard.object(forKey: nightKey) as? Bool ?? true }
    static var morningOn: Bool { UserDefaults.standard.object(forKey: morningKey) as? Bool ?? true }

    private static var observing = false

    /// アプリ 起動時に 1回:push-to-start の トークンを 控える
    static func startObserving() {
        guard !observing else { return }
        observing = true
        if #available(iOS 17.2, *) {
            Task {
                for await data in Activity<LattagLiveAttributes>.pushToStartTokenUpdates {
                    UserDefaults.standard.set(data.map { String(format: "%02x", $0) }.joined(), forKey: startTokenKey)
                }
            }
        }
        Task {
            for await activity in Activity<LattagLiveAttributes>.activityUpdates {
                Task {
                    for await data in activity.pushTokenUpdates {
                        UserDefaults.standard.set(data.map { String(format: "%02x", $0) }.joined(), forKey: pushTokenKey)
                    }
                }
            }
        }
    }

    /// スナップショット(最新)から 同期
    static func sync(snapshot: WidgetSnapshot, now: Date = Date()) {
        let model = WidgetModel.make(snapshot, now: now, filmShots: WidgetFilm.shots(now: now))
        sync(model: model, thumbs: model.shotBlurs, now: now, firstShot: model.shots > 0 ? snapshot.shotTimes.first : nil)
    }

    static func sync(model m: WidgetModel, thumbs: [String], now: Date = Date(), firstShot: Date? = nil) {
        let existing = Activity<LattagLiveAttributes>.activities
        // v134:1枚目を 撮ったら あした 9:00 まで 1つの 形(夜の 設定が オフなら 出さない)
        let waiting = nightOn && LattagLiveClock.isWaiting(shots: m.shots, now: now, opensAt: m.opensAt)
        let phase = waiting ? LattagLiveAttributes.Phase.waiting : LattagLiveClock.phase(now: now, shots: m.shots, shotYesterday: m.shots >= 1, night: nightOn, morning: morningOn)
        let key = LaterDay.key(for: now)
        guard let phase else {
            // 出さない 時間: 3枚 撮った / 24:00 なら 「現像に 入りました」で 終える。それ以外は すぐ 消す
            for a in existing {
                let done = a.content.state.phase == .film || a.content.state.phase == .lastCall
                var st = a.content.state; st.phase = .done; st.shotsTaken = m.shots
                let policy: ActivityUIDismissalPolicy = (done && m.shots >= 3) ? .after(now.addingTimeInterval(1800)) : (done ? .after(now.addingTimeInterval(3600)) : .immediate)
                Task { await a.end(ActivityContent(state: st, staleDate: nil), dismissalPolicy: policy) }
            }
            return
        }
        let isMorning = phase == .opening
        let ends = waiting ? m.opensAt : (isMorning ? LattagLiveClock.opens(now) : LattagLiveClock.lightsOut(now))
        let state = LattagLiveAttributes.ContentState(phase: phase, shotsTaken: m.shots, endsAt: ends, frameThumbs: Array(thumbs.prefix(3)),
                                                      friendCount: isMorning ? (m.yesterday?.people ?? 0) : m.friendsShot, devPercent: m.devPercent,
                                                      shotAt: waiting ? firstShot : nil)
        let content = ActivityContent(state: state, staleDate: ends)
        if let a = existing.first(where: { $0.attributes.dayKey == key }) {
            if a.content.state != state { Task { await a.update(content) } }
            for other in existing where other.id != a.id { Task { await other.end(nil, dismissalPolicy: .immediate) } }
        } else {
            for other in existing { Task { await other.end(nil, dismissalPolicy: .immediate) } }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try? Activity.request(attributes: LattagLiveAttributes(dayKey: key), content: content, pushType: .token)
        }
    }

    /// 「撮る」ボタン(島 ・ ラストコール)から ひらいた 時:撮影へ(60秒 いない)
    static func consumeOpenCamera() -> Bool {
        guard let d = UserDefaults(suiteName: LattagShared.appGroup) else { return false }
        let t = d.double(forKey: OpenCameraIntent.flagKey)
        guard t > 0 else { return false }
        d.removeObject(forKey: OpenCameraIntent.flagKey)
        return Date().timeIntervalSince1970 - t < 60
    }
}
