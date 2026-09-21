import FirebaseAuth
import Foundation

/// Sign in with Appleに加えた、メールのマジックリンク(パスワードレス)ログイン。
///
/// 前提として、Firebase Dynamic Linksは既に非推奨(2025年8月に廃止)のため、
/// このアプリではFirebase謹製のDynamic Linksに依存しない構成にしている:
/// メール内のリンクは(1)Universal Link/カスタムURLスキームで直接アプリへ渡ってくる
/// 場合はLaterApp.onOpenURLがそのまま拾う、(2)何らかの理由でブラウザ止まりになった
/// 場合に備え、リンクURLをアプリ内へ手動貼り付けできる入力欄もEmailSignInViewに
/// 用意している(どちらの経路でもcompleteSignIn(withLink:email:)へ合流する)。
enum FirebaseAuthService {
    private static let pendingEmailKey = "firebaseAuthPendingEmail"

    /// マジックリンクの送信先として使うURL。Firebaseプロジェクト(later-app-f2606)の
    /// 既定Hostingドメインを使う。
    static var actionCodeSettingsURL: URL {
        URL(string: "https://later-app-f2606.firebaseapp.com/finishSignIn")!
    }

    enum ServiceError: Error {
        case firebaseNotConfigured
        case missingEmail
    }

    /// 指定したメールアドレスへサインインリンクを送信する。送信したメールアドレスは
    /// ローカルに保存しておき(pendingEmail)、リンクを開いた際に同じ端末なら
    /// 自動的に補完できるようにする(別端末で開いた場合はEmailSignInView側で
    /// ユーザーに再入力してもらう)。
    static func sendSignInLink(to email: String) async throws {
        guard FirebaseConfigurator.isConfigured else { throw ServiceError.firebaseNotConfigured }
        let settings = ActionCodeSettings()
        settings.url = actionCodeSettingsURL
        settings.handleCodeInApp = true
        settings.setIOSBundleID(Bundle.main.bundleIdentifier ?? "")
        try await Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: settings)
        UserDefaults.standard.set(email, forKey: pendingEmailKey)
    }

    /// sendSignInLink(to:)の直後にこの端末へ保存された、送信先メールアドレス。
    static var pendingEmail: String? {
        UserDefaults.standard.string(forKey: pendingEmailKey)
    }

    static func isSignInLink(_ url: URL) -> Bool {
        guard FirebaseConfigurator.isConfigured else { return false }
        return Auth.auth().isSignIn(withEmailLink: url.absoluteString)
    }

    /// リンクとメールアドレスからサインインを完了する。
    @discardableResult
    static func completeSignIn(withLink link: String, email: String) async throws -> (uid: String, email: String?) {
        guard FirebaseConfigurator.isConfigured else { throw ServiceError.firebaseNotConfigured }
        guard !email.isEmpty else { throw ServiceError.missingEmail }
        let result = try await Auth.auth().signIn(withEmail: email, link: link)
        UserDefaults.standard.removeObject(forKey: pendingEmailKey)
        return (result.user.uid, result.user.email)
    }
}
