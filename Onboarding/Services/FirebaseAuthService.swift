import FirebaseAuth
import Foundation

/// v104:サインインは Apple だけ(`AppleFirebaseAuth`)。ここには 失敗の 表示まわりだけ のこす。
enum FirebaseAuthService {
    enum ServiceError: Error {
        case firebaseNotConfigured
        /// 本人が 途中で やめた
        case cancelled
    }

    /// 開発中とTestFlightのときだけ、失敗の内訳(domain / code / 名前)を画面の小さな文字で出す。
    /// App Store版では出さない。
    static var showsDebugDetails: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    /// 失敗の中身を1行にまとめる(画面表示とログの両方で使う)。
    static func debugLabel(for error: Error) -> String {
        let e = error as NSError
        let name = e.userInfo["FIRAuthErrorUserInfoNameKey"] as? String ?? "-"
        let inner = (e.userInfo[NSUnderlyingErrorKey] as? NSError).map { " / inner \($0.domain) \($0.code)" } ?? ""
        return "\(e.domain) \(e.code) \(name)\(inner)"
    }
}
