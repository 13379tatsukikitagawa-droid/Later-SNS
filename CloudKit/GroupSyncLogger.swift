import os

/// LaterGroup.toCKRecord・CircleCreateGroupView.createGroup・
/// GroupSharingService.createGroupなど、グループ作成〜CloudKit同期の経路で
/// 共通して使う診断ログ用Logger。printはRelease(TestFlight)ビルドでは
/// Console.app/Xcode Organizerから確認できないため、代わりにos.Loggerを使う。
enum GroupSyncLogger {
    static let shared = Logger(subsystem: "com.tatsukikitagawa.laternew2", category: "GroupSync")
}
