import BackgroundTasks
import SwiftData

/// アプリを開かなくても、iOSのバックグラウンド更新のタイミングで期限切れ写真を
/// 片付けるための仕組み(第7-3章)。CloudKitはPrivate/Sharedデータベースに
/// サーバー側の定期実行が無いため、これは「クライアント側の強化」であって、
/// 誰のデバイスも起動しない場合にまで消えることを保証するものではない。
enum BackgroundMaintenance {
    static let taskIdentifier = "jp.shotoku.later.prune"
    /// v86:Recap を 月曜 9:00 / 1日 9:00 の 直後に 先に 作る(動かなくても ひらいた 時に 作る ので 取りこぼさない)
    static let recapIdentifier = "app.lattag.recap"

    /// AppDelegate.didFinishLaunchingWithOptionsから、アプリが実際に起動を終える前に呼ぶこと
    /// (BGTaskSchedulerの要件)。
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(task: refreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: recapIdentifier, using: nil) { task in
            guard let t = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            handleRecap(task: t)
        }
    }

    /// 次の 月曜 9:00 の すこし 後に 予約(月の Recap は 1日 9:00 の 後の 月曜 まで に ひらいた 時 でも 作る)
    static func scheduleRecap() {
        let request = BGAppRefreshTaskRequest(identifier: recapIdentifier)
        request.earliestBeginDate = RecapRules.nextMonday9(after: Date()).addingTimeInterval(120)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRecap(task: BGAppRefreshTask) {
        scheduleRecap()
        let context = ModelContext(LaterApp.sharedModelContainer)
        let work = Task { @MainActor in
            let me = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
            let kept = Set(me?.pinnedPhotoIDs ?? [])
            let shots = (me?.photos ?? []).map { RecapShot(id: $0.id.uuidString, date: $0.captureDate, tag: $0.tags.first, kept: kept.contains($0.id)) }
            RecapStore.shared.refresh(now: Date(), shots: shots)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel(); task.setTaskCompleted(success: false) }
    }

    /// 次回分を積む。フォアグラウンドに戻った時・バックグラウンドに退いた時の両方から呼んでよい
    /// (重複申請はBGTaskSchedulerが無視する)。
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
        scheduleRecap()
    }

    private static func handle(task: BGAppRefreshTask) {
        schedule()

        let context = ModelContext(LaterApp.sharedModelContainer)
        let work = Task { @MainActor in
            PhotoExpiryMaintenance.pruneExpired(context: context, cloudKitManager: CloudKitManager.current)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
