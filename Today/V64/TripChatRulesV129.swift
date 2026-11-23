import SwiftUI

// P57 B(v129 2章):Trip の チャットの きまり(画面を 持たない)。

enum TripChatRules {
    /// よく使う ことば(入力の 上の 横スクロール ・ 押すと すぐ 送る)
    static let quickPhrases = ["はよ 撮って", "いま どこ?", "撮った!", "9:00 たのしみ", "おつかれ"]

    static let photoNote = "ひらいた 写真 だけ 送れる(きょうの 分は あした 9:00 から)"

    /// ステッカー 8つ(形と 色 だけ ・ 顔は 作らない)。`ChatMessage.stickerId` に `id` を 入れる
    struct Art: Identifiable {
        let id: String
        let shape: PopShape
        let color: Color
        let tilt: Double
    }

    static let stickers: [Art] = [
        .init(id: "star-sun", shape: .star, color: PopColor.sun, tilt: -6),
        .init(id: "heart-pink", shape: .heart, color: PopColor.pink, tilt: 5),
        .init(id: "spark-sky", shape: .spark, color: PopColor.sky, tilt: -4),
        .init(id: "flower-lime", shape: .flower, color: PopColor.lime, tilt: 6),
        .init(id: "hash-lime", shape: .hash, color: PopColor.lime, tilt: -5),
        .init(id: "star-pink", shape: .star, color: PopColor.pink, tilt: 4),
        .init(id: "heart-sky", shape: .heart, color: PopColor.sky, tilt: -6),
        .init(id: "spark-sun", shape: .spark, color: PopColor.sun, tilt: 5),
    ]

    static func art(_ id: String?) -> Art? { stickers.first { $0.id == id } }

    // MARK: 写真(ひらいた 写真 だけ)

    /// **きょう 撮った 写真は 送れない**(あした 9:00 の 解禁を 守る)。`PhotoDevelop` と 同じ 1つの 判定
    static func canSendPhoto(takenAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        PhotoDevelop.isDeveloped(takenAt: takenAt, now: now, calendar: calendar)
    }

    /// 送れる 写真の 一覧(ひらいた 物 だけ ・ 新しい 順)
    static func sendable<T>(_ items: [T], takenAt: (T) -> Date, now: Date, calendar: Calendar = .current) -> [T] {
        items.filter { canSendPhoto(takenAt: takenAt($0), now: now, calendar: calendar) }.sorted { takenAt($0) > takenAt($1) }
    }

    // MARK: 一覧の 並べ方

    enum Item: Identifiable, Equatable {
        case day(id: String, label: String)
        case system(ChatMessage)
        case bubble(ChatMessage, first: Bool, last: Bool, mine: Bool)

        var id: String {
            switch self {
            case .day(let id, _): return id
            case .system(let m): return "s-" + m.id
            case .bubble(let m, _, _, _): return m.id
            }
        }
    }

    /// 続けて 送った 物の かたまりの きまり(同じ 人 ・ 同じ 日 ・ 5分 いない)
    static let clusterGap: TimeInterval = 5 * 60

    /// 日が かわる 所に `DAY 2 ・ 11/21(土)` の 札。続けて 送った 物は 1つの かたまり
    static func items(_ messages: [ChatMessage], me: String?, tripStart: Date, calendar: Calendar = .current) -> [Item] {
        let df = DateFormatter(); df.locale = Locale(identifier: "ja_JP"); df.dateFormat = "MM/dd(E)"
        let start = calendar.startOfDay(for: tripStart)
        var out: [Item] = []
        var lastDay: Date?
        for (i, m) in messages.enumerated() {
            let day = calendar.startOfDay(for: m.sentAt)
            if day != lastDay {
                lastDay = day
                let n = max(1, (calendar.dateComponents([.day], from: start, to: day).day ?? 0) + 1)
                out.append(.day(id: "day-\(Int(day.timeIntervalSinceReferenceDate))", label: "DAY \(n) ・ \(df.string(from: day))"))
            }
            if m.kind == .system { out.append(.system(m)); continue }
            let prev = i > 0 ? messages[i - 1] : nil
            let next = i + 1 < messages.count ? messages[i + 1] : nil
            let joinsPrev = prev.map { joins($0, m, calendar) } ?? false
            let joinsNext = next.map { joins(m, $0, calendar) } ?? false
            out.append(.bubble(m, first: !joinsPrev, last: !joinsNext, mine: m.senderId == me))
        }
        return out
    }

    private static func joins(_ a: ChatMessage, _ b: ChatMessage, _ cal: Calendar) -> Bool {
        a.kind != .system && b.kind != .system && a.senderId == b.senderId
            && b.sentAt.timeIntervalSince(a.sentAt) <= clusterGap && cal.isDate(a.sentAt, inSameDayAs: b.sentAt)
    }

    /// 字が 空でも 送れる 物(ステッカー ・ 写真)は 別。字は 空白だけ なら 送らない
    static func canSendText(_ draft: String) -> Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 通知(v129 D)

/// Trip の チャットの 通知の きまり(画面も 通信も 持たない)
enum TripChatPushRules {
    /// Worker からの 通知(`kind == trip_chat` ・ `tripId` = LaterGroup.id の 小文字)の 行き先の グループ
    static func groupID(fromPush userInfo: [AnyHashable: Any]) -> UUID? {
        guard userInfo["kind"] as? String == "trip_chat", let raw = userInfo["tripId"] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    /// アプリを ひらいて いる 時の バナー:**いま ひらいて いる 部屋の 通知は 出さない**(音も 出さない)
    static func shouldPresentInForeground(userInfo: [AnyHashable: Any], openRoom: UUID?) -> Bool {
        guard let id = groupID(fromPush: userInfo) else { return true }
        return id != openRoom
    }

    /// 端末で 出す ローカル通知(「新しい メッセージが あります」)は、Worker の プッシュが 有効な 間は 出さない(同じ メッセージで 2回 鳴らさない)
    static func shouldPostLocal(useWorker: Bool, isOpenRoom: Bool, muted: Bool) -> Bool {
        !useWorker && !isOpenRoom && !muted
    }
}
