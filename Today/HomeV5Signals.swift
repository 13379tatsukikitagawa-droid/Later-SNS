import SwiftUI

/// 撮影後の Home の3つのタブ
enum HomeTab: Hashable {
    case mondo, group, calendar
}

/// Home v5 のあいだ、画面のあちこちから共有する小さな状態。
@MainActor
@Observable
final class HomeV5Signals {
    static let shared = HomeV5Signals()

    /// はじめての説明を出している間
    var isShowingGuide = false
    /// 写真ビューア・グループの部屋・カレンダーの日の詳細・Mondo の設定・位置の確認・通報などが重なっている間は、撮影画面への入口を受けない
    var blocksCameraEntry = false
    /// 3つのタブのうち、いま見ているもの
    var activeTab: HomeTab = .mondo
    /// 画面の下から、タブバーの上端までの高さ
    var tabBarExtra: CGFloat = 0
    /// はじめての使い方カードが出ている間
    var isShowingCoach = false

    private init() {}
}

// MARK: - はじめての使い方カード

/// 撮影のあと、はじめてこの画面に来たときに1回だけ出す、ガラスのカード。
struct TabsCoachCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            row(icon: "rectangle.3.group", title: "下のタブで、切りかえ", detail: "Mondo・グループ・カレンダー")
            row(icon: "hand.tap", title: "アイコンを、2回タップ", detail: "今日 ⇄ 昨日 のホームを切りかえ")
            Button(action: onDismiss) {
                Text("わかった")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Capsule().fill(Color(hex: "FFB277")))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: 340)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.ultraThinMaterial))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .padding(.horizontal, 28)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "FFB277"))
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
