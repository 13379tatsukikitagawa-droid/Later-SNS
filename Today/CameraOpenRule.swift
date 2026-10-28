import SwiftUI

// 撮影画面をひらく入口(月のタップ・VoiceOver)の共通ルール。
// - CameraOpenRule:ひらくか・ことわるかの判定(純粋なロジック。テストはここ)。
// - CameraDeniedCard:撮れないときの、画面中央のガラスのカード。
// 写真は、ひらいただけでは撮らない(シャッターの長押し1.5秒だけが撮る)。

/// 撮影画面をひらくときの判定
enum CameraOpenRule {
    /// 前に受けつけた要求から、この秒数は無視する
    static let openDebounce: TimeInterval = 0.9
    /// 触覚のあと、撮影画面をひらくまでの秒数
    static let openDelay: TimeInterval = 0.3
    /// ことわりのカードを出す秒数
    static let deniedCardSeconds: TimeInterval = 1.6
    /// 撮影画面を下へ払って閉じる距離(pt)
    static let swipeDownToClose: CGFloat = 120
    /// 撮影画面を左へ払って閉じる距離(pt)
    static let swipeLeftToClose: CGFloat = 110

    enum Decision: Equatable {
        /// 何もしない
        case ignore
        /// ひらく
        case open
        /// 3こま撮りきった
        case deniedShotsUsed
        /// 夜(24:00〜9:00)
        case deniedNight
    }

    /// - isBlocked: 撮影画面・シート・ビューア・入力中など、受けつけない状態
    static func decide(
        isBlocked: Bool,
        now: Date,
        lastAccepted: Date?,
        canShoot: Bool,
        isNight: Bool,
        shotsToday: Int
    ) -> Decision {
        guard !isBlocked else { return .ignore }
        if let lastAccepted, now.timeIntervalSince(lastAccepted) < openDebounce { return .ignore }
        if isNight { return .deniedNight }
        guard canShoot, FilmRoll.shotsRemaining(shotsToday: shotsToday) > 0 else { return .deniedShotsUsed }
        return .open
    }

    /// 撮影画面をひらけるか(HomeState の canShoot と、のこりのこま)
    static func canOpen(canShoot: Bool, shotsToday: Int) -> Bool {
        canShoot && FilmRoll.shotsRemaining(shotsToday: shotsToday) > 0
    }

    /// ことわりのカードの言葉(太字, 小)
    static func deniedCopy(_ decision: Decision) -> (title: String, detail: String)? {
        switch decision {
        case .deniedShotsUsed: return ("今日は、ここまで", "3こま、撮りました")
        case .deniedNight: return ("おやすみの時間", "9:00に、3こま届く")
        default: return nil
        }
    }

    /// VoiceOver 用のことわり
    static func deniedSpoken(_ decision: Decision) -> String? {
        switch decision {
        case .deniedShotsUsed: return "今日は、ここまで。あしたの9:00に3こま届く"
        case .deniedNight: return "おやすみの時間。9:00に、3こま届く"
        default: return nil
        }
    }
}

// MARK: - ことわりのカード

/// 撮れないとき、画面の中央に1.6秒だけ出すガラスのカード
struct CameraDeniedCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.ultraThinMaterial))
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)。\(detail)")
        .allowsHitTesting(false)
    }
}
