import Foundation

// v134 Phase 2:Home の 文言と 状態の 決まり(純粋な ロジック。テストは ここ)。
// 夜 = 0:00〜9:00(消灯)。「ひらく」の 時刻は 撮った 日の 翌朝 9:00(`PhotoDevelop` と 同じ)。

enum HomeV134Rules {
    // MARK: 今日の フィルム(下の アクセサリ)

    struct FilmStatus: Equatable {
        var title: String
        var sub: String
        var shortLabel: String
        var target: Date
        /// #レンズが 鍵の 状態(消灯中 ・ 3枚 撮りきった あと)
        var lensLocked: Bool
        var night: Bool
    }

    static func isNight(_ now: Date, calendar: Calendar = .current) -> Bool { calendar.component(.hour, from: now) < 9 }

    static func filmStatus(shots: Int, now: Date, calendar: Calendar = .current) -> FilmStatus {
        let todayNine = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let tomorrowNine = calendar.date(byAdding: .day, value: 1, to: todayNine) ?? now.addingTimeInterval(86400)
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        if isNight(now, calendar: calendar) {
            return .init(title: "消灯中", sub: "あかりがつくまで", shortLabel: "9:00まで", target: todayNine, lensLocked: true, night: true)
        }
        if shots <= 0 {
            return .init(title: "今日のフィルム", sub: "24:00の消灯まで、あと3枚", shortLabel: "消灯まで", target: midnight, lensLocked: false, night: false)
        }
        let n = min(3, shots)
        return .init(title: "今日のフィルム \(n)/3", sub: "あしたの9:00にひらく", shortLabel: "ひらくまで", target: tomorrowNine, lensLocked: n >= 3, night: false)
    }

    // MARK: あなたのきのう(カード)

    enum CardButton: Equatable { case shoot, tomorrow, from9 }

    struct YesterdayCard: Equatable {
        var line1: String
        var line2: String?
        var button: CardButton
    }

    static func yesterdayCard(opened: Int, total: Int, shots: Int, night: Bool) -> YesterdayCard {
        let button: CardButton = shots >= 3 ? .tomorrow : (night ? .from9 : .shoot)
        if total <= 0 {
            return .init(line1: "はじめての1枚を撮ろう", line2: night ? "9:00に、あかりがついたら撮れる" : nil, button: button)
        }
        if opened >= total { return .init(line1: "きのうは、ぜんぶひらいた", line2: nil, button: button) }
        if opened <= 0 {
            return .init(line1: night ? "9:00に、あかりがついたら撮れる" : "今日を1枚撮ると、1枚ひらく", line2: nil, button: button)
        }
        return .init(line1: "\(opened)枚ひらいた", line2: "あと\(total - opened)枚は、撮るたびにひらく", button: button)
    }

    // MARK: 待った時間(unlockDate − captureDate の 近似 = 翌朝 9:00 − 撮った 時刻)

    static func unlockTime(captured: Date, calendar: Calendar = .current) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: captured) ?? captured
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextDay) ?? nextDay
    }

    /// 例 "16h20m"
    static func waitedLabel(captured: Date, calendar: Calendar = .current) -> String {
        let secs = max(0, Int(unlockTime(captured: captured, calendar: calendar).timeIntervalSince(captured)))
        return String(format: "%dh%02dm", secs / 3600, (secs % 3600) / 60)
    }

    // MARK: 日付の 書き方

    /// 例 "11.25 WED"
    static func dayLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "M.dd EEE"
        return f.string(from: d).uppercased()
    }

    /// 例 "'26 11 25"(写真の 日付スタンプ)
    static func stamp(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "''yy MM dd"
        return f.string(from: d)
    }

    /// 例 "16:42"
    static func clock(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    // MARK: 見ないで待った(自分だけに 見える 数字 ・ シェアカード)

    /// 例 "19H 18M"(シェアカード)
    static func waitedBig(captured: Date, calendar: Calendar = .current) -> String {
        let secs = max(0, Int(unlockTime(captured: captured, calendar: calendar).timeIntervalSince(captured)))
        return String(format: "%dH %02dM", secs / 3600, (secs % 3600) / 60)
    }

    /// その 月に 撮った 写真が 待った 時間の 合計(時間)と、日ごとの 時間(1日 = index 0)
    static func waitedTotals(captures: [Date], month: Date, calendar: Calendar = .current) -> (hours: Int, perDay: [Double]) {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return (0, []) }
        var per = [Double](repeating: 0, count: range.count)
        for c in captures where calendar.isDate(c, equalTo: month, toGranularity: .month) {
            let h = unlockTime(captured: c, calendar: calendar).timeIntervalSince(c) / 3600
            let d = calendar.component(.day, from: c) - 1
            if per.indices.contains(d) { per[d] += max(0, h) }
        }
        return (Int(per.reduce(0, +).rounded(.down)), per)
    }

    // MARK: GOOD MORNING(9:00 以降に はじめて ひらいた とき 1日1回)

    static func dayKey(_ d: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// きのう 撮った 写真が あり、9:00 を すぎて いて、きょうは まだ 出して いない
    static func shouldShowGoodMorning(now: Date, lastShownDay: String?, hasYesterday: Bool, calendar: Calendar = .current) -> Bool {
        hasYesterday && !isNight(now, calendar: calendar) && lastShownDay != dayKey(now, calendar: calendar)
    }
    // MARK: v136 ともだち 0人の Home

    /// ともだちが 0人(自分を のぞく)。0人の Home は #レンズが 主役。
    static func hasNoFriends(friendCount: Int) -> Bool { friendCount <= 0 }

    /// レンズの 直径。大きい 画面は 168。低い 画面(iPhone SE 375×667)は、レンズと「QRを見せる / IDでさがす」が スクロールなしで 見える 大きさまで 小さくする(下限 100)。
    static func lensDiameter(screenHeight h: CGFloat) -> CGFloat {
        min(168, max(100, 168 - max(0, 780 - h) * 0.6))
    }
}

/// 「1日1回」の 目じるし(日付だけ UserDefaults に 書く)
enum GoodMorningStore {
    static let key = "goodMorning.lastDay"
    static var lastShownDay: String? { UserDefaults.standard.string(forKey: key) }
    static func markShown(now: Date = Date()) { UserDefaults.standard.set(HomeV134Rules.dayKey(now), forKey: key) }
}
