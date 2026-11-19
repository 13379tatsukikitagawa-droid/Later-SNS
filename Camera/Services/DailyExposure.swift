import Foundation
import Observation
import SwiftData

/// 撮った写真を「見せてよいか」の、ただ1つの判定(Later の約束)。
/// 撮った写真は、撮ったあとで最初に来る 9:00(端末の時刻)まで、自分にも見せない(現像中)。
/// Home の「じぶん」・Profile・グループの画面は、必ずここを使う。
/// ※ 端末の時計に頼っている(時計を進めると早く見える)。いまはそれを許す。
enum PhotoDevelop {
    /// 仕上がる時刻:takenAt のあとで、最初に来る 9:00(9:00 ちょうどに撮ったら、次の日の 9:00)
    static func developDate(takenAt: Date, calendar: Calendar = .current) -> Date {
        // 撮れる窓(特別な日に のびることがある)では なく、時計の 9:00 で 決める
        let start = calendar.startOfDay(for: takenAt)
        let sameDay = calendar.date(byAdding: .minute, value: DailyExposureRules.openingHour * 60, to: start) ?? start
        if takenAt < sameDay { return sameDay }
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? takenAt
        return calendar.date(byAdding: .minute, value: DailyExposureRules.openingHour * 60, to: nextDay) ?? nextDay
    }

    /// 仕上がったか(now が仕上がる時刻を過ぎているか)
    static func isDeveloped(takenAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        now >= developDate(takenAt: takenAt, calendar: calendar)
    }

    /// まだ開けないものを押したときの、短い一言
    static let lockedNote = "あしたの朝、仕上がります"
}

/// 【B】前日の 自分の写真が ひらいているか(ただ1つの 判定)。
/// - 今日(いまの窓)の 写真:つぎの 9:00 まで 現像中
/// - 前日の 写真:今日 **保存できた** 枚数だけ、撮った順(古い方から)に ひらく。のこりは「あと◯こま」
/// - それより 前の 写真:ひらいている
/// 保存できた 写真(端末の LaterPhoto)から 毎回 計算するので、アプリを 閉じても 戻らない。9:00 で 数えなおす
enum OwnReveal {
    enum Status: Equatable {
        /// 今日の 写真(9:00 まで)
        case developing
        case open
        /// 前日の 写真:今日 あと shots こま 撮ると ひらく
        case waiting(shots: Int)

        var isOpen: Bool { self == .open }
        /// ぼかしに 出す 短い文(「あと2こま」/「9:00 に ひらく」)
        var lockedText: String? {
            switch self {
            case .open: return nil
            case .developing: return "9:00 に ひらく"
            case .waiting(let n): return "あと\(n)こま"
            }
        }
    }

    /// ownCaptureDates:自分が 撮って 保存できた 写真の 時刻(グループごとの 写しは まとめなくてよい)。
    /// 省略すると、OwnShotLedger(端末の 写真から 作った 一覧)を 使う
    static func status(takenAt: Date, now: Date, ownCaptureDates: [Date]? = nil, calendar: Calendar = .current) -> Status {
        let latest = DailyWindow.latest(for: now, calendar: calendar)
        if takenAt >= latest.open { return .developing }
        let yesterday = DailyWindow.yesterday(for: now, calendar: calendar)
        guard takenAt >= yesterday.open, takenAt < yesterday.close else { return .open }
        let dates = distinct(ownCaptureDates ?? OwnShotLedger.shared.captureDates)
        let yesterdayShots = dates.filter { $0 >= yesterday.open && $0 < yesterday.close }
        let index = yesterdayShots.firstIndex { abs($0.timeIntervalSince(takenAt)) < 1 } ?? yesterdayShots.filter { $0 < takenAt }.count
        let savedToday = dates.filter { $0 >= latest.open && $0 < latest.close && $0 <= now }.count
        return index < savedToday ? .open : .waiting(shots: index + 1 - savedToday)
    }

    static func isOpen(takenAt: Date, now: Date, ownCaptureDates: [Date]? = nil, calendar: Calendar = .current) -> Bool {
        status(takenAt: takenAt, now: now, ownCaptureDates: ownCaptureDates, calendar: calendar).isOpen
    }

    /// 前日の 写真が、今日 何枚 ひらいたか(= min(今日 保存できた枚数, 前日の枚数))
    static func openedYesterdayCount(now: Date, ownCaptureDates: [Date]? = nil, calendar: Calendar = .current) -> Int {
        let latest = DailyWindow.latest(for: now, calendar: calendar)
        let yesterday = DailyWindow.yesterday(for: now, calendar: calendar)
        let dates = distinct(ownCaptureDates ?? OwnShotLedger.shared.captureDates)
        let y = dates.filter { $0 >= yesterday.open && $0 < yesterday.close }.count
        let t = dates.filter { $0 >= latest.open && $0 < latest.close && $0 <= now }.count
        return min(y, t)
    }

    /// 同じ 1枚(グループごとの 写し)は 1つに。古い順
    static func distinct(_ dates: [Date]) -> [Date] {
        var seen = Set<Int>()
        return dates.sorted().filter { seen.insert(Int($0.timeIntervalSinceReferenceDate.rounded())).inserted }
    }
}

/// 自分が 撮って 保存できた 写真の 時刻(端末の LaterPhoto から TodayView が 作る)。
/// 写真の 一覧を 持たない 画面(カレンダー・プロフィールなど)も、OwnReveal で 同じ 判定が できるように
@MainActor @Observable
final class OwnShotLedger {
    static let shared = OwnShotLedger()
    private static let key = "ownShotLedger.v1"

    private(set) var captureDates: [Date]

    private init() {
        let stored = UserDefaults.standard.array(forKey: Self.key) as? [Double] ?? []
        captureDates = stored.map { Date(timeIntervalSinceReferenceDate: $0) }
    }

    func update(_ dates: [Date]) {
        let next = OwnReveal.distinct(dates)
        guard next != captureDates else { return }
        captureDates = next
        UserDefaults.standard.set(next.map(\.timeIntervalSinceReferenceDate), forKey: Self.key)
    }
}

/// 「今日の1枚」の撮影ルール(Later 基本ルール 再設計版 §2・§3)。
/// 実機で調整・変更しやすいよう、数値はすべてここに集める。
enum DailyExposureRules {
    /// 撮影スタートの時刻(全員同時)。
    static let openingHour = 9
    /// 1枚に付けられるタグの上限(「最大3つ」は案。変える時はここだけ直す)。
    static let maxTags = 3
    /// 露光(長押し)に必要な時間。
    static let holdDuration: TimeInterval = 1.5
    /// 写真の画像(CKAsset)を、撮った時点でCloudKitへ送るか(v3)。falseなら、従来どおり
    /// グループの解禁(isUnlocked)まで画像を送らない。
    static let uploadsImageAtCapture = true

    /// 0:00〜9:00 も 撮れる 特別な日(その日の 0:00〜9:00 は、前の日の 窓の つづき)。
    /// 2026-11-08:この日だけ(確認用)。おわったら この行を 消す
    static let openNights: Set<String> = ["2026-11-08"]

    /// 指定日の撮影時間帯(開始・終了)。9:00〜翌0:00。
    /// openNights の 日は、前の日の 窓が その日の 9:00 まで のびる(0:00〜9:00 も 撮れる)
    static func window(for date: Date, calendar: Calendar = .current) -> (open: Date, close: Date) {
        let startOfToday = calendar.startOfDay(for: date)
        let open = calendar.date(byAdding: .minute, value: openingHour * 60, to: startOfToday) ?? startOfToday
        var close = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        // 0:00〜9:00 が 撮れる日の 夜中:前の日の(のびた)窓に 入る
        if date < open, openNights.contains(dayKey(startOfToday, calendar: calendar)),
           let previous = calendar.date(byAdding: .day, value: -1, to: startOfToday) {
            return window(for: previous, calendar: calendar)
        }
        // あしたが 0:00〜9:00 も 撮れる日なら、きょうの 窓は あしたの 9:00 まで
        if openNights.contains(dayKey(close, calendar: calendar)) {
            close = calendar.date(byAdding: .minute, value: openingHour * 60, to: close) ?? close
        }
        return (open, close)
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 撮影を始めてよいか。長押しを開始した瞬間の時刻を渡す(押している間に枠を跨いでも有効)。
    /// 撮影時間帯の外と、今日の枚数が上限(FilmRoll.shotsPerDay)に達している場合は始められない。
    static func canBeginExposure(at date: Date, shotsToday: Int, calendar: Calendar = .current) -> Bool {
        guard shotsToday < FilmRoll.shotsPerDay else { return false }
        let window = window(for: date, calendar: calendar)
        return date >= window.open && date < window.close
    }

    /// 撮影時間帯の終わりまでの残り時間。撮影時間外はnil。
    static func remainingUntilLightsOut(from now: Date, calendar: Calendar = .current) -> TimeInterval? {
        let window = window(for: now, calendar: calendar)
        guard now >= window.open, now < window.close else { return nil }
        return window.close.timeIntervalSince(now)
    }

    /// 指定ユーザーが、dateと同じ日にすでに撮影しているか(1日1枚の判定)。
    static func hasShot(on date: Date, by user: UserProfile, calendar: Calendar = .current) -> Bool {
        user.photos.contains { calendar.isDate($0.captureDate, inSameDayAs: date) }
    }

    /// 撮影時に選べる「みんながよく使うタグ」。集計の仕組みができるまでは固定の候補を出す。
    static let suggestedTags = ["朝ごはん", "空", "散歩", "仕事", "カフェ", "夜", "家", "通学", "ひとり", "友だち"]

    // MARK: - 写真の寿命(撮ってから7日)

    /// 写真(本体・サムネ・「預けた日々」の点)を見られる期間(日)。
    static let photoRetentionDays = 7

    /// 撮った日(アプリの「その日」)から photoRetentionDays 日後の9:00(消える時刻)。
    /// 例: 10/01に撮った写真 → 10/08の9:00に消える。
    static func expiryDate(capturedAt: Date, calendar: Calendar = .current) -> Date {
        let dayN = calendar.date(byAdding: .day, value: photoRetentionDays, to: calendar.startOfDay(for: capturedAt)) ?? capturedAt
        return calendar.date(byAdding: .hour, value: openingHour, to: dayN) ?? dayN
    }

    /// 消えるまでの残り日数(カレンダー日単位)。すでに期限を過ぎていれば0。
    static func remainingDaysUntilExpiry(capturedAt: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let expiry = expiryDate(capturedAt: capturedAt, calendar: calendar)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiry)).day ?? 0
        return max(0, days)
    }

    /// 期限(撮った日から7日後の9:00)を過ぎているか。
    static func isExpired(capturedAt: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        now >= expiryDate(capturedAt: capturedAt, calendar: calendar)
    }
}

/// 1日に撮れる枚数(3こまフィルム)と、昨日の写真の解禁の数え方。
/// 上限は端末の枚数で数える。CloudKit は、ここで決めた数を強制しない(サーバー側の判定は別の作業)。
enum FilmRoll {
    /// 1日に撮れる枚数。変える時はここだけ直す。
    static let shotsPerDay = 3

    /// 特別な日だけ、撮れる数を かえる(キーは LaterDay.key:その日の 9:00 〜 翌 0:00)。
    /// 2026-11-08:この日だけ 15枚(確認用)。おわったら この行を 消す
    /// 2026-11-07 の 日(11/8 の 0:00〜9:00 も ふくむ)も 15枚
    static let specialCapacities: [String: Int] = ["2026-11-07": 15, "2026-11-08": 15]

    /// その日に 撮れる 上限(ふだんは shotsPerDay)。表示の こまの数(3つ)・昨日の ひらく数(最大3)には 使わない
    static func capacity(now: Date = Date(), calendar: Calendar = .current) -> Int {
        specialCapacities[LaterDay.key(for: now, calendar: calendar)] ?? shotsPerDay
    }

    /// 今日のこり(0以上)。
    static func shotsRemaining(shotsToday: Int) -> Int {
        max(0, shotsPerDay - shotsToday)
    }

    /// 解禁の権利の数 = min(今日の枚数, 昨日の枚数) − すでにひらいた数(0以上)。
    /// 例:昨日3・今日2 → 2。昨日1・今日3 → 1。
    static func unlockCredits(shotsToday: Int, shotsYesterday: Int, opened: Int) -> Int {
        max(0, min(shotsToday, shotsYesterday) - opened)
    }

    /// 指定の撮影時刻のうち、同じ1枚を指すものを1つに数える(グループごとの複製は撮影時刻が同じ)。
    static func distinctShotCount(_ captureDates: [Date]) -> Int {
        Set(captureDates).count
    }
}

/// 期限切れの写真を端末とCloudKitから取り除く(第7章)。RootViewの通常の起動時/フォア
/// グラウンド復帰時と、BGAppRefreshTask(アプリを開かなくても定期的に)の両方から呼ぶ。
@MainActor
enum PhotoExpiryMaintenance {
    /// 消えた件数。
    @discardableResult
    static func pruneExpired(context: ModelContext, cloudKitManager: CloudKitManager?, now: Date = Date()) -> Int {
        // 決めないまま次の9:00をすぎた昨日の1枚も、ここで静かに消す
        YesterdayPostStore.pruneUndecided(context: context, cloudKitManager: cloudKitManager, now: now)
        // 端末に残った加工済み画像・送信用の一時ファイルのうち、期限(撮ってから7日)を過ぎたものを消す
        let retentionCutoff = now.addingTimeInterval(-Double(DailyExposureRules.photoRetentionDays) * 86_400)
        ChekiColorGrade.removeDiskCache(olderThan: retentionCutoff)
        CKAssetTempFiles.removeStale(now: now)
        guard let allPhotos = try? context.fetch(FetchDescriptor<LaterPhoto>()) else { return 0 }
        let expired = allPhotos.filter { DailyExposureRules.isExpired(capturedAt: $0.captureDate, now: now) }
        guard !expired.isEmpty else { return 0 }
        for photo in expired {
            cloudKitManager?.markForDelete(photo: photo)
            // v20 動画:本体も、ポスター(image)と同じタイミングで消す(えらんだ1つは MEPickStore に写しがある)
            LaterVideoStore.deleteLocal(photo.videoFileName)
            context.delete(photo)
        }
        try? context.save()
        return expired.count
    }
}

/// 撮った1枚を保存する。プレビューも投稿先選択も挟まず、撮影の瞬間に呼ばれる。
/// 保存先は自分のME(個人スペース)と、参加しているすべてのグループ
/// (「みんな」= 同じグループの人)。CloudKitへの送信は投稿準備画面
/// (PostTargetGroupSelectionView.submitPost)と同じ流れを使う。
@MainActor
enum DailyExposureStore {
    enum SaveError: Error {
        case noDestination
    }

    static func save(
        imageData: Data,
        captureDate: Date,
        tags: [String],
        locationName: String?,
        user: UserProfile,
        groups: [LaterGroup],
        context: ModelContext,
        dayExtras: ExposureDayStore.Extras? = nil,
        video: (fileName: String, duration: Double)? = nil,
        music: MusicPick? = nil
    ) throws {
        guard !groups.isEmpty else { throw SaveError.noDestination }

        // 解禁前の表示に使う、とても小さな画像(22 × 48 px)。1枚につき1度だけ作る。
        let mosaicTiny = MosaicRenderer.makeTiny(from: imageData)
        var inserted: [(photo: LaterPhoto, group: LaterGroup)] = []
        for group in groups {
            // unlockDateは解禁の瞬間にCloudKitManager.evaluateGroupUnlockConditionsが上書きする。
            let photo = LaterPhoto(imageData: imageData, captureDate: captureDate, unlockDate: captureDate, owner: user)
            photo.tags = tags
            photo.authorCloudKitUserRecordName = CloudKitManager.current?.currentUserRecordName
            photo.authorNameCache = user.name
            photo.locationName = locationName
            photo.groupID = group.id
            photo.groupNameCache = group.name
            photo.mosaicTiny = mosaicTiny
            photo.filmVersion = dayExtras?.filmVersion
            if dayExtras?.filmVersion == FilmLook.version { photo.isColorGraded = true }   // 焼きずみ(解禁の 直前に もう 焼かない)
            // v20 動画:ポスター(最初のコマ)は imageData。本体は端末のファイル(グループごとの写しで同じファイルを指す)
            if let video {
                photo.durationSeconds = video.duration
                photo.videoFileName = video.fileName
            }
            // v22 L-4:今日の 1曲(つけていなければ 何も 入れない)
            photo.applyMusic(music)
            // 位置の共有を「撮った場所」にしたグループだけ、丸めた位置を添える
            GroupLocationService.stamp(photo, groupID: group.id, isPersonalSpace: group.isPersonalSpace)
            // 撮った時点では画像以外だけを届ける。画像は翌日「投稿する」を選んだときに送る。
            photo.isPosted = false
            context.insert(photo)
            group.photos.append(photo)
            inserted.append((photo, group))
        }

        do {
            try context.save()
        } catch {
            for (photo, _) in inserted { context.delete(photo) }
            throw error
        }
        // プロフィールの「預けた日々」用に、その日の記録(色・小さなサムネイル)を1度だけ作る。
        // 色・サムネイルが先に(メインの外で)作ってあれば、それを使う(メインで写真をデコードしない)
        ExposureDayStore.record(imageData: imageData, captureDate: captureDate, locationName: locationName, context: context, extras: dayExtras)

        // Mondo への公開は、翌日「投稿する」を選んだとき(YesterdayPostStore.post)。

        guard let cloudKitManager = CloudKitManager.current else { return }
        Task {
            for (photo, group) in inserted {
                await cloudKitManager.markForUpload(photo: photo, in: group)
                cloudKitManager.markGroupDirty(group.id)
            }
            await cloudKitManager.evaluateGroupUnlockConditions()
            await cloudKitManager.sendPendingChangesNow()
        }
    }
}

/// 昨日の自分の1枚を「投稿する / しない」(撮る → 昨日の1枚が解禁 → 投稿するか選ぶ)。
/// 撮った時点では画像以外(撮影者・時刻・タグ・場所)だけがグループに届いている。
/// 選択は端末にすぐ反映し、送信はCKSyncEngineの保留(アプリを閉じても残る)で、つながったら届ける。
@MainActor
enum YesterdayPostStore {
    /// 昨日の窓の、自分の写真(グループごとの複製を含む)
    static func yesterdayOwnPhotos(of user: UserProfile, now: Date, calendar: Calendar = .current) -> [LaterPhoto] {
        let window = DailyWindow.yesterday(for: now, calendar: calendar)
        return user.photos.filter { $0.captureDate >= window.open && $0.captureDate < window.close }
    }

    /// 投稿する:画像をグループに送り、Mondo(公開がオンのときだけ・審査あり)に出す。
    static func post(_ photos: [LaterPhoto], user: UserProfile, context: ModelContext) {
        let pending = photos.filter { !$0.isPosted }
        guard let first = pending.first else { return }
        for photo in pending { photo.isPosted = true }
        try? context.save()

        let imageData = first.imageData, captureDate = first.captureDate, tags = first.tags, name = user.name, photoID = first.id
        Task { @MainActor in
            let result = await MondoService.shared.publishIfEnabled(imageData: imageData, captureDate: captureDate, tags: tags, name: name, photoID: photoID)
            if result == .notAllowed { MondoNotice.post("この写真は Mondo には出せません") }
        }

        guard let cloudKitManager = CloudKitManager.current else { return }
        let targets = pending.compactMap { photo -> (LaterPhoto, LaterGroup)? in
            guard let groupID = photo.groupID, let group = user.groups.first(where: { $0.id == groupID }) else { return nil }
            return (photo, group)
        }
        Task {
            for (photo, group) in targets {
                await cloudKitManager.markForUpload(photo: photo, in: group)
                cloudKitManager.markGroupDirty(group.id)
            }
            await cloudKitManager.sendPendingChangesNow()
        }
    }

    /// 【D】投稿しない:共有の場所(グループ)の レコードだけ 消して、ほかの人には 何も 残さない。
    /// 自分の 端末には 残す(ME・カレンダー・★の 対象。7日で 消えるのは 同じ)
    static func skip(_ photos: [LaterPhoto], context: ModelContext) {
        let pending = photos.filter { !$0.isPosted && !$0.postDeclined }
        guard !pending.isEmpty else { return }
        let manager = CloudKitManager.current
        for photo in pending {
            photo.postDeclined = true
            manager?.markForDelete(photo: photo)
        }
        try? context.save()
        Task { await manager?.sendPendingChangesNow() }
    }

    /// 決めないまま次の9:00になった自分の写真を、静かに消す(「投稿しない」と同じ扱い)。
    @discardableResult
    static func pruneUndecided(context: ModelContext, cloudKitManager: CloudKitManager?, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let deadline = DailyWindow.yesterday(for: now, calendar: calendar).open
        // 「投稿しない」を 選んだ 写真は 消さない(端末に 残す。7日で 消える)
        let descriptor = FetchDescriptor<LaterPhoto>(predicate: #Predicate { !$0.isPosted && !$0.postDeclined && $0.captureDate < deadline })
        guard let candidates = try? context.fetch(descriptor) else { return 0 }
        // 他の人の未投稿のレコード(画像なし)も端末に届いているので、自分の分だけを消す
        let me = UserProfile.current(from: (try? context.fetch(FetchDescriptor<UserProfile>())) ?? [])
        let myRecordName = cloudKitManager?.currentUserRecordName
        let mine = candidates.filter { photo in
            (me != nil && photo.owner?.id == me?.id)
                || (myRecordName != nil && photo.authorCloudKitUserRecordName == myRecordName)
        }
        guard !mine.isEmpty else { return 0 }
        // ひらかないまま(または 決めないまま)9:00 を すぎた 写真を 消す。枚数を のこす
        let count = OwnReveal.distinct(mine.map(\.captureDate)).count
        CloudDiagnostics.record("決めないまま 9:00 を すぎた 写真を 消した", "\(count)枚(グループごとの 写しを ふくめて \(mine.count)件)")
        delete(mine, context: context, cloudKitManager: cloudKitManager)
        return mine.count
    }

    private static func delete(_ photos: [LaterPhoto], context: ModelContext, cloudKitManager: CloudKitManager?) {
        guard !photos.isEmpty else { return }
        let dayKeys = Set(photos.map { ExposureDayStore.dayKey(for: $0.captureDate) })
        for photo in photos {
            cloudKitManager?.markForDelete(photo: photo)
            context.delete(photo)
        }
        if let days = try? context.fetch(FetchDescriptor<ExposureDay>()) {
            for day in days where dayKeys.contains(day.dayKey) { context.delete(day) }
        }
        try? context.save()

        let mondoID = MondoIdentity.id
        let records = dayKeys.map { MondoIdentity.recordName(mondoID: mondoID, dayKey: $0) }.filter(MondoLocalStore.published.contains)
        Task {
            if !records.isEmpty { await MondoService.shared.withdraw(records) }
            await cloudKitManager?.sendPendingChangesNow()
        }
    }
}

// MARK: - 動画の撮影(長押しの長さで、写真・動画・捨てるを分ける)

/// 長押しを離したときに、何を残すか。
enum ExposureOutcome: Equatable {
    /// 1.5秒より前に離した:何も残さない
    case discard
    /// 1.5秒〜2.0秒で離した:写真だけ
    case photoOnly
    /// 2.0秒より長く押し続けた:動画(写真は1.5秒の1コマ)
    case video
}

/// プレビューの表示の仕方。既定は覗き窓に映像を出す(撮る場所が見えるように)。
enum PreviewMode: Equatable {
    /// 画面に映像を出さない(以前の探究の条件。切り替えはVideoExposureRules.previewModeだけで行う)
    case blind
    /// 覗き窓に外カメラの映像を出す
    case visible
}

enum VideoExposureRules {
    /// 動画になる長さ(これより長く押し続けたら動画)
    static let videoThreshold: TimeInterval = 2.0
    /// 動画の最大の長さ(15.0秒で自動終了)
    static let maxDuration: TimeInterval = 15
    /// 「ふわ」の合図を出す録画の経過秒
    static let softMarks: [TimeInterval] = [5, 10]
    /// 覗き窓に映像を出す。切り替えは、この定数だけを直す
    static let previewMode: PreviewMode = .visible

    /// 押していた長さ(秒)と、録画できたかで、残すものを決める。
    static func outcome(heldFor seconds: TimeInterval, canRecord: Bool) -> ExposureOutcome {
        guard seconds >= DailyExposureRules.holdDuration else { return .discard }
        guard canRecord, seconds > videoThreshold else { return .photoOnly }
        return .video
    }
}
