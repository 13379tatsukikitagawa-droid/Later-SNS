import BackgroundTasks
import SwiftData

/// アプリを開かなくても、iOSのバックグラウンド更新のタイミングで期限切れ写真を
/// 片付けるための仕組み(第7-3章)。CloudKitはPrivate/Sharedデータベースに
/// サーバー側の定期実行が無いため、これは「クライアント側の強化」であって、
/// 誰のデバイスも起動しない場合にまで消えることを保証するものではない。
enum BackgroundMaintenance {
    static let taskIdentifier = "jp.shotoku.later.prune"

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
    }

    /// 次回分を積む。フォアグラウンドに戻った時・バックグラウンドに退いた時の両方から呼んでよい
    /// (重複申請はBGTaskSchedulerが無視する)。
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
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
