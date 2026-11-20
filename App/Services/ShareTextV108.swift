import Foundation
import SwiftData

/// v108 §5-2:LINE などへ 送る 文。リンクは すべて https(`?openExternalBrowser=1`)。絵文字は 使わない。
enum ShareTextV108 {
    static func friend(name: String, handle: String) -> String? {
        guard !handle.isEmpty, let url = AppLinks.friendURL(handle: handle) else { return nil }
        return "\(name)(@\(handle))から Lattag の 友だち申請です\n\n↓ タップで ひらく(アプリが ひらきます)\n\(url.absoluteString)\n\nアプリが ない 時は、ひらいた ページから 入れられます"
    }

    /// `dates` / `members` は わからない 時は 省く。KEY は「#maple24」でも「maple24」でも よい
    static func trip(host: String, name: String, dates: String?, members: Int?, key: String) -> String {
        let k = key.hasPrefix("#") ? String(key.dropFirst()) : key
        let url = AppLinks.tripURL(token: k)?.absoluteString ?? ""
        var detail = "『\(name)』"
        if let dates, !dates.isEmpty { detail += dates }
        if let members, members > 0 { detail += " ・ \(members)人 参加中" }
        return "\(host) から Trip の 招待です\n\(detail)\n\n↓ タップで 参加(アプリが ひらきます)\n\(url)\n\nKEY:#\(k)(アプリの「KEY で 入る」でも OK ・ 24時間)"
    }

    /// "NOV 17" → "11/17"
    static func shortDate(_ s: String) -> String? {
        let months = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6, "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]
        let parts = s.uppercased().split(separator: " ")
        guard parts.count == 2, let m = months[String(parts[0])], let d = Int(parts[1]) else { return nil }
        return "\(m)/\(d)"
    }

    @MainActor static var me: (name: String, handle: String) {
        let p = UserProfile.current(from: (try? LaterApp.sharedModelContainer.mainContext.fetch(FetchDescriptor<UserProfile>())) ?? [])
        return (p?.name ?? "", HandleRules.normalize(p?.username ?? ""))
    }
}

extension FriendRules {
    /// 自分の 友だちリンク(QR にも 入る)。ID が あれば https、無い 時だけ 古い later://friend(送る 文には 使わない)
    @MainActor static func shareLink(recordName: String) -> URL {
        let h = ShareTextV108.me.handle
        if !h.isEmpty, let u = AppLinks.friendURL(handle: h) { return u }
        return link(recordName: recordName)
    }
    /// 送る 文(友だち)。ID が 無い 時だけ 名前 + リンクの 古い 文
    @MainActor static func shareText(myName: String, recordName: String) -> String {
        let me = ShareTextV108.me
        return ShareTextV108.friend(name: myName.isEmpty ? me.name : myName, handle: me.handle) ?? "\(myName) と Lattag で つながろう\n\(link(recordName: recordName).absoluteString)"
    }
}
