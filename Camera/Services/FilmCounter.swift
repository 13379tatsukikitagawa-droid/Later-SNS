import Foundation
import Observation

/// 「のこり」を数える、ただ1つの場所(v22 A)。
/// 数えるのは、シャッターが切れた瞬間の1回だけ(写真は 1.5秒の長押しが終わった時、動画は 1秒以上で止めた時)。
/// 保存・アップロードが失敗しても、減った分は戻さない。どこの画面も、のこりはここだけを見る。
/// 日の区切りは LaterDay.key(9:00 開始。0:00〜9:00 は前の日の続き)。App Group に保存するので、再起動しても残る。
@MainActor @Observable
final class FilmCounter {
    static let shared = FilmCounter()

    /// ふだんの 1日に撮れる数(表示の こまの数)
    static let limit = FilmRoll.shotsPerDay

    static let dayKeyKey = "filmCounter.dayKey"
    static let usedIDsKey = "filmCounter.usedIDs"

    /// 数えている日(LaterDay.key)
    private(set) var dayKey: String
    /// 使ったこまの ID(使った順)
    private(set) var usedIDs: [String]

    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let calendar: Calendar
    /// その日の 上限(ふだん 3。特別な日だけ かわる:FilmRoll.capacity)
    @ObservationIgnored private let capacityFor: (Date, Calendar) -> Int

    /// 今日の 上限
    var limit: Int { capacityFor(clock(), calendar) }

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: LaterWidgetShared.appGroup),
        clock: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        capacity: @escaping (Date, Calendar) -> Int = { FilmRoll.capacity(now: $0, calendar: $1) }
    ) {
        self.defaults = defaults
        self.clock = clock
        self.calendar = calendar
        self.capacityFor = capacity
        let now = LaterDay.key(for: clock(), calendar: calendar)
        let savedKey = defaults?.string(forKey: Self.dayKeyKey)
        if savedKey == now {
            dayKey = now
            usedIDs = defaults?.stringArray(forKey: Self.usedIDsKey) ?? []
        } else {
            dayKey = now
            usedIDs = []
        }
    }

    private var currentKey: String { LaterDay.key(for: clock(), calendar: calendar) }

    /// 今日、使ったこま(日がかわっていれば 0。読むだけで、書きかえない)
    var used: Int {
        guard dayKey == currentKey else { return 0 }
        return min(limit, usedIDs.count)
    }

    /// 今日のこり(0〜3)
    var remaining: Int { max(0, limit - used) }

    /// シャッターが切れた瞬間に1回だけ呼ぶ。数えられたら true、もう上限なら false。同じ ID は2回数えない。
    /// source は "screen" / "volume" / "movie"(ログ用)
    @discardableResult
    func consume(captureID: UUID, source: String) -> Bool {
        rollOverIfNeeded()
        let id = captureID.uuidString
        if usedIDs.contains(id) { return true }
        guard usedIDs.count < limit else {
            #if DEBUG
            print("[Film] consume refused id=\(id) source=\(source) remaining=0")
            #endif
            return false
        }
        usedIDs.append(id)
        save()
        // v96:ウィジェット(レンズ ・ 9:00 まで ・ ロック)は App Group の こまを 読む。すぐ 書きなおす
        WidgetSnapshotWriter.reloadAfterShot()
        #if DEBUG
        print("[Film] consume id=\(id) source=\(source) remaining=\(remaining)")
        #endif
        return true
    }

    /// 端末やほかの端末に残っている撮影(ID)を合わせる。和集合(順番は保つ)で、増えるだけ。減らさない。
    func reconcile(serverIDs: [String]) {
        rollOverIfNeeded()
        var merged = usedIDs
        for id in serverIDs where !merged.contains(id) {
            guard merged.count < limit else { break }
            merged.append(id)
        }
        guard merged != usedIDs else { return }
        usedIDs = merged
        save()
    }

    /// 保存ずみの写真(撮影ごとのキー)から合わせる。いま数えた分(まだ保存中)と二重にならないよう、
    /// 足りない数だけを足す(昔の写真・ほかの端末の撮影も数に入る)。
    func reconcile(savedKeys: [String]) {
        rollOverIfNeeded()
        let distinct = Array(NSOrderedSet(array: savedKeys)) as? [String] ?? savedKeys
        let missing = distinct.count - usedIDs.count
        guard missing > 0 else { return }
        reconcile(serverIDs: Array(distinct.filter { !usedIDs.contains($0) }.prefix(missing)))
    }

    /// 日がかわっていたら、0 にもどす(9:00 をまたいだ時)。画面が時計で更新される時に呼ぶ。
    func refresh() { rollOverIfNeeded() }

    /// 保存に 失敗した(写真が 返らなかった・保存の形に できなかった):最後に 数えた 1こまを 戻す
    func refundLast(reason: String) {
        rollOverIfNeeded()
        guard !usedIDs.isEmpty else { return }
        usedIDs.removeLast()
        save()
        #if DEBUG
        print("[Film] refund reason=\(reason) remaining=\(remaining)")
        #endif
    }

    #if DEBUG
    /// テスト・見た目の確認用:今日の 使ったこまを 置きかえる(保存しない)
    func debugReplace(used: Int) {
        rollOverIfNeeded()
        usedIDs = (0..<max(0, min(limit, used))).map { _ in UUID().uuidString }
    }
    #endif

    private func rollOverIfNeeded() {
        let key = currentKey
        guard dayKey != key else { return }
        dayKey = key
        usedIDs = []
        save()
    }

    private func save() {
        defaults?.set(dayKey, forKey: Self.dayKeyKey)
        defaults?.set(usedIDs, forKey: Self.usedIDsKey)
    }
}
