import Foundation
import Observation

/// v106 §1:「はじめての 設定が おわった」の 決まり(純粋な 関数・テストする)。
/// - おわった = さいごの ながおしの あとに `onboardedAt` が 書かれた 人。
/// - 前から いる 人:名前の 入った 記録が この 版より 前に できて いれば おわった 人 と して あつかう。
/// - それ以外(途中の 人)は、つづきの ページへ。途中で 書いた もの(ID の 予約 ・ 写真)では Home に 行かない。
enum OnboardingRouter {
    /// この 版の 前 / 後の 境目(2026-11-20 00:00 JST)
    static let legacyCutoff = Date(timeIntervalSince1970: 1_795_100_400)

    enum Gate: Equatable {
        case finished          // onboardedAt が ある → おかえり → Home
        case legacyFinished    // 前から いる 人 → Home + onboardedAt を あとから 書く
        case resume            // つづきの ページへ
    }

    static func gate(name: String, onboardedAt: Date?, recordCreatedAt: Date?) -> Gate {
        if onboardedAt != nil { return .finished }
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let c = recordCreatedAt, c < legacyCutoff { return .legacyFinished }
        return .resume
    }

    /// 保存して ある ページ(`onboardingStep`)から 出す 場面。サインイン 済みか どうかで 決める
    static func resume(saved: String, signedIn: Bool) -> OBStep? {
        guard !saved.isEmpty else { return nil }
        guard let s = OBStep(rawValue: saved) else { return signedIn ? .name : .signin }
        switch s {
        case .mail, .sent, .signin: return signedIn ? .name : .signin
        default: return signedIn ? s : .signin
        }
    }
}

/// ながおしの 演出の 間だけ、うしろに Home を 用意する ための 印(のこさない)
@MainActor @Observable
final class OnboardingRuntime {
    static let shared = OnboardingRuntime()
    var finishing = false
}
