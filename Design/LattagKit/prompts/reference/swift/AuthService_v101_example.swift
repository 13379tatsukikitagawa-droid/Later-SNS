// 参考(形の 見本)・ そのまま コピー しない。PROMPT_v101.md が 正解。型名 ・ 置き場所は 今の プロジェクトに 合わせる。
// 必要:FirebaseAuth 11.8 以上(linkDomain)・ GoogleSignIn-iOS(SPM)・ Associated Domains = applinks:<PROJECT_ID>.firebaseapp.com
import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@MainActor
final class AuthService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case sending                       // O25
        case sent(email: String)           // O06
        case signingIn                     // O27
        case needEmail(link: String)       // O29(ちがう 端末)
        case linkExpired                   // O30
        case exists(email: String?)        // O31
        case failed(message: String, debug: String)   // O26
        case signedIn(isNewUser: Bool)     // → Name か O28 おかえり
    }
    @Published var phase: Phase = .idle
    private var pendingCredential: AuthCredential?            // 5章:あとで つなぐ

    private let linkDomain = "<PROJECT_ID>.firebaseapp.com"   // 定数 1か所(Info.plist から 読んでも よい)
    private let emailKey = "auth.pendingEmail"

    // MARK: - Google(2章)
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID, let top = UIApplication.topViewController else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let r = try await GIDSignIn.sharedInstance.signIn(withPresenting: top)
            guard let idToken = r.user.idToken?.tokenString else { return }
            let cred = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: r.user.accessToken.tokenString)
            try await finish(with: cred)
        } catch {
            if (error as? GIDSignInError)?.code == .canceled { Haptics.play(.soft); return }   // キャンセル = 何も 出さない
            show(error)
        }
    }

    // MARK: - メールの リンク(3章)
    func sendLink(to email: String) async {
        phase = .sending
        let s = ActionCodeSettings()
        s.url = URL(string: "https://\(linkDomain)/finishSignIn")
        s.handleCodeInApp = true
        s.setIOSBundleID(Bundle.main.bundleIdentifier!)
        s.linkDomain = linkDomain                      // dynamicLinkDomain は 使わない(2025/8 で 停止)
        do {
            try await Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: s)
            UserDefaults.standard.set(email, forKey: emailKey)
            phase = .sent(email: email)
        } catch { show(error) }
    }

    /// .onOpenURL と .onContinueUserActivity の 両方から 呼ぶ。メールの リンク なら true。
    @discardableResult
    func handleIncoming(_ url: URL) -> Bool {
        let link = url.absoluteString
        guard Auth.auth().isSignIn(withEmailLink: link) else { return false }
        if let email = UserDefaults.standard.string(forKey: emailKey) {
            Task { await completeEmail(email, link: link) }
        } else {
            phase = .needEmail(link: link)              // O29
        }
        return true
    }

    func completeEmail(_ email: String, link: String) async {
        phase = .signingIn
        Haptics.play(.projector)
        do {
            let r = try await Auth.auth().signIn(withEmail: email, link: link)
            UserDefaults.standard.removeObject(forKey: emailKey)
            try await afterSignIn(r)
        } catch { show(error) }
    }

    // MARK: - 共通
    private func finish(with cred: AuthCredential) async throws {
        let r = try await Auth.auth().signIn(with: cred)
        try await afterSignIn(r)
    }

    private func afterSignIn(_ r: AuthDataResult) async throws {
        if let p = pendingCredential {                  // 5章:前の 方法で 入れたら、新しい 方法も つなぐ
            _ = try? await r.user.link(with: p)
            pendingCredential = nil
        }
        Haptics.play(.success)
        // 4章:プロフィールが あるか(場所は 0章で しらべた もの)
        let exists = await ProfileStore.exists(uid: r.user.uid)
        phase = .signedIn(isNewUser: !exists)
    }

    private func show(_ error: Error) {
        let e = error as NSError
        let code = AuthErrorCode(rawValue: e.code)
        let debug = "\(e.domain) \(e.code) \(e.userInfo["FIRAuthErrorUserInfoNameKey"] as? String ?? "")"
        switch code {
        case .expiredActionCode?, .invalidActionCode?:
            phase = .linkExpired
        case .accountExistsWithDifferentCredential?:
            pendingCredential = e.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
            phase = .exists(email: e.userInfo[AuthErrorUserInfoEmailKey] as? String)
        case .invalidEmail?:
            phase = .failed(message: "メールアドレスの 形を たしかめて ください", debug: debug)
        case .operationNotAllowed?, .unauthorizedDomain?, .invalidContinueURI?, .unauthorizedContinueURI?:
            phase = .failed(message: "今は この 方法が 使えません", debug: debug)
        case .tooManyRequests?, .quotaExceeded?:
            phase = .failed(message: "少し まって、もう一度", debug: debug)
        case .networkError?:
            phase = .failed(message: "通信を たしかめて、もう一度", debug: debug)
        default:
            phase = .failed(message: "うまく いきませんでした。もう一度", debug: debug)
        }
        Haptics.play(.warn)
        #if DEBUG
        print("[Auth]", debug)                           // リリースでは メールや トークンを 出さない
        #endif
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}

// App 側(どちらでも 受ける)
// WindowGroup {
//   RootView()
//     .onOpenURL { url in
//       if GIDSignIn.sharedInstance.handle(url) { return }
//       auth.handleIncoming(url)
//     }
//     .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { ua in
//       if let url = ua.webpageURL { auth.handleIncoming(url) }
//     }
// }

extension UIApplication {
    static var topViewController: UIViewController? {
        var vc = shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}
