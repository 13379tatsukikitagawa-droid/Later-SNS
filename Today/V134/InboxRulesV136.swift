import Foundation

// v136:通知の画面(ベル)の 決まりごと。見た目から 切りはなして テストできる 形に する。
// ベルの 数 = 友だち申請 + Trip の 招待。ともだちの 人数は どこにも 数えない。
enum InboxRulesV136 {
    static func badge(requests: Int, tripInvites: Int) -> Int { max(0, requests) + max(0, tripInvites) }

    // MARK: 通知の 許可カード

    enum PermissionAction: Equatable { case turnOn, openSettings }
    struct PermissionCard: Equatable {
        let title: String
        let body: String
        let button: String
        let action: PermissionAction
    }
    /// 許可ずみなら カードは 出さない。「許可しない」の あとは 許可の 画面を 出せないので 設定アプリへ。
    static func permissionCard(_ p: NotifPermission) -> PermissionCard? {
        let title = "通知がオフになっています"
        let body = "9:00に写真がひらいたときと、申請が来たときに知らせます"
        switch p {
        case .on: return nil
        case .unset: return PermissionCard(title: title, body: body, button: "オンにする", action: .turnOn)
        case .off: return PermissionCard(title: title, body: body, button: "設定をひらく", action: .openSettings)
        }
    }

    // MARK: 「今日」「今週」

    enum Bucket: Int, CaseIterable { case today, week
        var title: String { self == .today ? "今日" : "今週" }
    }
    /// きょう = 今日 ・ 6日まえまで = 今週 ・ それより 古い 物は 出さない。
    static func bucket(of date: Date, now: Date, calendar: Calendar = .current) -> Bucket? {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        let d0 = calendar.startOfDay(for: date), n0 = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: d0, to: n0).day ?? 99
        return (days > 0 && days < 7) ? .week : nil
    }

    // MARK: ともだちが 0人 ・ 通知が ない 時に 「ここに 来るもの」

    static let emptyTitle = "まだ通知はありません"
    static let comingLines = ["ともだち申請", "Tripの招待", "9:00に写真がひらいたとき"]
}
