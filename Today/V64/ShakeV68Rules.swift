import Foundation

/// Shake(v68)の 純粋な 決まり。通信 ・ センサーとは 切りはなして、テストで 確かめる。
/// 大事な 決まり:**ふった 時刻は 端末の 時計どうしで くらべない**。ふったら すぐ 相手に 送り、
/// うけとった 側が「自分の 時計で、自分が ふった 時刻 と うけとった 時刻」を くらべる。
enum ShakeV68Rules {
    /// ふったと みなす 大きさ(G)
    static let threshold = 2.2
    /// この 秒数の 中で 2回 こえたら「ふった」
    static let doubleWindow = 0.65
    /// 自分が ふった 時刻 と 相手の「ふった」を うけとった 時刻の 差(どちらも 自分の 時計)が これ 以内なら ペア
    static let pairWindow: TimeInterval = 2.0
    /// 「つながる」を 両方 押すまで 待つ 秒数
    static let confirmWindow: TimeInterval = 60
    /// ふっても 見つからない とき あきらめる 秒数
    static let seekTimeout: TimeInterval = 8
    /// 10分に 20回まで
    static let maxShakes = 20
    static let rateWindow: TimeInterval = 600
    /// 同時に 見せる 人数の 上限
    static let maxCandidates = 5

    static func isPair(myShake: Date, receivedAt: Date) -> Bool {
        abs(receivedAt.timeIntervalSince(myShake)) <= pairWindow
    }

    /// 2台の うち 1回きりの 合言葉が 小さい 方だけ 招待する(同時に 招待しあって 二重に つながるのを 防ぐ)
    static func shouldInvite(myNonce: String, theirNonce: String) -> Bool { myNonce < theirNonce }

    static func canShake(history: [Date], now: Date) -> Bool {
        history.filter { now.timeIntervalSince($0) < rateWindow }.count < maxShakes
    }

    static func pruned(_ history: [Date], now: Date) -> [Date] { history.filter { now.timeIntervalSince($0) < rateWindow } }

    struct Candidate: Equatable { let id: String }

    enum Verdict: Equatable { case show, alreadyFriend, hidden }

    /// 候補に して よいか。**ブロックが ある 人 ・ 申請を 断った 相手 ・ 自分が 取り消した 相手は 出さない**。
    static func verdict(for id: String, me: String, friends: Set<String>, blocked: Set<String>, declined: Set<String>, cancelled: Set<String>) -> Verdict {
        if id == me || id.isEmpty { return .hidden }
        if blocked.contains(id) || declined.contains(id) || cancelled.contains(id) { return .hidden }
        if friends.contains(id) { return .alreadyFriend }
        return .show
    }

    /// 重なった 申請:自分 → 相手 と 相手 → 自分 が 両方 ある 相手(承認ボタン なしで 成立させる)。断った / 取り消した / ブロックは 除く。
    static func crossed(outgoing: Set<String>, incomingFrom: [String], excluded: Set<String>) -> [String] {
        var seen = Set<String>()
        return incomingFrom.filter { outgoing.contains($0) && !excluded.contains($0) && seen.insert($0).inserted }
    }
}

/// ふった ことを 見つける(加速度の 大きさ G を 1つずつ 入れる)。山が 2回 0.65秒 以内に 来たら true。
struct ShakeDetector {
    private var peaks: [Double] = []
    private var armed = true

    mutating func feed(time: Double, g: Double) -> Bool {
        peaks.removeAll { time - $0 > ShakeV68Rules.doubleWindow }
        if g >= ShakeV68Rules.threshold, armed {
            armed = false
            peaks.append(time)
            if peaks.count >= 2 { peaks.removeAll(); return true }
        } else if g < 1.6 {
            armed = true
        }
        return false
    }

    mutating func reset() { peaks.removeAll(); armed = true }
}

/// 自分が 取り消した 相手(端末の 中だけ)。取り消しの 操作が できた とき `add` する。Shake の 候補に 出さない。
enum ShakeExclusions {
    private static let key = "shake.cancelled.v1"
    static var cancelled: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }
    static func add(_ id: String) { cancelled.insert(id) }
}
