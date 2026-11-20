import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation

/// v104 P47 A:Apple で 入る 所を 1か所に まとめる。Apple の 認証 → nonce つきで Firebase に のせる(`uid` で 見分ける)。
/// 今まで Apple だけで 入って いた 人は appleUserID を のこしたまま firebaseUID を 足す(ログアウトさせない)。
enum AppleFirebaseAuth {
    /// 元の nonce(Firebase へ)と、Apple へ わたす SHA256
    struct Nonce { let raw: String; var hashed: String { Self.sha256(raw) }
        static func make() -> Nonce {
            var bytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            return Nonce(raw: bytes.map { String(format: "%02x", $0) }.joined())
        }
        static func sha256(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
    }

    enum AuthFailure: Error { case notConfigured, noToken, userMismatch }

    /// Apple の 結果を Firebase に のせて uid を かえす。成功したら firebaseUID(UserDefaults)にも 書く
    @discardableResult
    static func signIn(_ credential: ASAuthorizationAppleIDCredential, rawNonce: String, expectedAppleUser: String? = nil) async throws -> String {
        guard FirebaseConfigurator.isConfigured else { throw AuthFailure.notConfigured }
        if let expectedAppleUser, credential.user != expectedAppleUser { throw AuthFailure.userMismatch }
        guard let tokenData = credential.identityToken, let idToken = String(data: tokenData, encoding: .utf8) else { throw AuthFailure.noToken }
        let firebaseCredential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: credential.fullName)
        let result = try await Auth.auth().signIn(with: firebaseCredential)
        UserDefaults.standard.set(result.user.uid, forKey: "firebaseUID")
        if let email = result.user.email { UserDefaults.standard.set(email, forKey: "firebaseEmail") }
        return result.user.uid
    }

    /// つなぎなおしが 要る 人(Apple で 入って いるが Firebase の uid が 無い)
    static var needsReconnect: Bool {
        let d = UserDefaults.standard
        return !(d.string(forKey: "appleUserID") ?? "").isEmpty && (d.string(forKey: "firebaseUID") ?? "").isEmpty && FirebaseConfigurator.isConfigured
    }

    /// 起動の たびに:Firebase に すでに 入って いる(キーチェーンに のこって いる)なら uid だけ ひろう
    @MainActor static func adoptExistingSession() {
        guard FirebaseConfigurator.isConfigured, let u = Auth.auth().currentUser else { return }
        let d = UserDefaults.standard
        if (d.string(forKey: "firebaseUID") ?? "") != u.uid, !(d.string(forKey: "appleUserID") ?? "").isEmpty { d.set(u.uid, forKey: "firebaseUID") }
    }

    /// Worker に わたす ID トークン(期限が 近ければ 更新)
    static func idToken() async -> String? {
        guard FirebaseConfigurator.isConfigured, let u = Auth.auth().currentUser else { return nil }
        return try? await u.getIDToken()
    }
}
