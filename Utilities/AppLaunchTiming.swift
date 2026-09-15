import Foundation

/// アプリ起動からHome画面表示までの時間を計測するための、起動時刻の記録。
/// `processStart`はstatic letなので初回アクセス時に評価される。LaterApp.init()の
/// 冒頭でアクセスすることで、アプリコード内で可能な限り早いタイミングの時刻を掴む。
enum AppLaunchTiming {
    static let processStart = CFAbsoluteTimeGetCurrent()

    private static var hasReportedHomeDisplayed = false

    /// Home画面(TodayShootingView)が初めて実際に表示された時点で1回だけ呼ぶ。
    static func reportHomeDisplayedIfNeeded() {
        guard !hasReportedHomeDisplayed else { return }
        hasReportedHomeDisplayed = true
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - processStart) * 1000
        PerformanceSignpost.event("AppLaunchToHome", detail: String(format: "%.1fms", elapsedMs))
    }
}
