import FirebaseCore
import Foundation

/// FirebaseApp.configure()(引数なし版)は、GoogleService-Info.plistが見つからない/
/// 壊れている場合にfatalErrorでアプリごと落ちる。GoogleService-Info.plistの配置は
/// Firebaseコンソール側の準備が整うまで後回しにできるようにしたいため、
/// 呼び出す前に必ずバンドル内の存在を確認し、無ければ何もせず安全にスキップする
/// (この間、メールのマジックリンクログインは「準備中」として扱われ、
/// Sign in with Appleは通常通り使える)。
enum FirebaseConfigurator {
    private static var didAttemptConfigure = false

    /// GoogleService-Info.plistがバンドルに含まれているか。
    static var isConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    /// アプリ起動時に一度だけ呼ぶ。GoogleService-Info.plistが無ければ何もしない。
    static func configureIfPossible() {
        guard !didAttemptConfigure else { return }
        didAttemptConfigure = true
        guard isConfigured else {
            print("[Firebase] GoogleService-Info.plistが見つからないため、Firebase Authenticationは無効のままです(Sign in with Appleは通常通り使えます)。")
            return
        }
        FirebaseApp.configure()
    }
}
