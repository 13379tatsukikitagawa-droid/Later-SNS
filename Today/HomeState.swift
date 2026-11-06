import Foundation
import SwiftUI
import UIKit

/// Home画面の状態(再設計 Step 2 + v2)。現在時刻と、自分の撮影日時などだけから決まる。
/// 判定はresolveの1か所にまとめ、現在時刻を外から渡せるようにしている。
enum HomeState: Equatable {
    /// 夜(00:00〜09:00)・直近の窓(前日9:00〜当日0:00)で撮影ずみ。
    case night
    /// 夜(00:00〜09:00)・直近の窓で撮らなかった。
    case rest
    /// 昼・まだ撮っていない・昨日以前の写真がまだ1枚もない(初日)。
    case first
    /// 昼・まだ撮っていない(昨日の写真が待っている)。
    case dawn
    /// 昼・今日の窓で撮った・昨日の自分の1枚を、まだ「投稿する / しない」決めていない。
    case deciding(shotAt: Date)
    /// 昼・今日の窓で撮った・(昨日の自分の1枚がない、または決めた)・まだ昨日をひらいていない。
    /// shotAtは今日の1枚の撮影時刻。
    case ready(shotAt: Date)
    /// 昼・今日の窓で撮った・昨日をひらいたあと。
    case opened(shotAt: Date)
    /// 昼・昨日をひらいたあと・今日のこまがまだ残っている(3こまのうち、まだ撮れる)。
    /// remainingは今日のこり(1〜2)。shotAtは今日いちばん新しい1枚の撮影時刻。
    case more(shotAt: Date, remaining: Int)

    /// 撮影できる状態(dawn・first・more)か。
    var canShoot: Bool {
        switch self {
        case .dawn, .first, .more: return true
        default: return false
        }
    }

    /// 夜(月が暗い・撮れない)か。
    var isNight: Bool {
        switch self {
        case .night, .rest: return true
        default: return false
        }
    }

    /// 見出し・ボタンのクロスフェードの単位
    var kind: String {
        switch self {
        case .night: return "night"
        case .rest: return "rest"
        case .first: return "first"
        case .dawn: return "dawn"
        case .deciding: return "deciding"
        case .ready: return "ready"
        case .opened: return "opened"
        case .more: return "more"
        }
    }
}

/// 昨日の自分の1枚を、投稿するか。窓ごとに決めるので、9:00 で必ずリセットされる
/// (「昨日」の窓が1つ進み、決める対象そのものが変わる)。
enum YesterdayDecision: Equatable {
    case undecided
    case posted
    /// 投稿しない(写真は削除ずみ)
    case skipped

    /// 昨日の窓の自分の写真から決める。昨日の自分の1枚がなければnil。
    /// 「投稿しない」を選んだ写真は消えているので、ここではnilになる(skippedと同じ扱い)。
    static func resolve(yesterdayOwnPosted: [Bool]) -> YesterdayDecision? {
        guard !yesterdayOwnPosted.isEmpty else { return nil }
        return yesterdayOwnPosted.allSatisfy { $0 } ? .posted : .undecided
    }
}

extension HomeState {
    /// - Parameters:
    ///   - now: 現在時刻(テスト・プレビューでは任意の時刻を渡す)
    ///   - myCaptureDates: 自分が撮った写真の撮影日時(グループごとの重複は含んでいてよい)
    ///   - hasDeposited: これまでに1枚でも預けたか(写真が7日で削除された後も、記録から判定する)
    ///   - openedWindowKey: 最後に長押しで昨日をひらいた窓(DailyWindow.key)。直近の窓と同じ時だけ
    ///     「ひらいた」とみなすため、窓が変わる9:00ちょうどで必ずリセットされる。
    ///   - yesterdayDecision: 昨日の窓の自分の1枚の決定。昨日の自分の1枚がなければnil。
    ///   - filmUsed: 今日シャッターを切った数(FilmCounter.used)。「あと○こま」はこれで決める。
    static func resolve(
        now: Date,
        myCaptureDates: [Date],
        hasDeposited: Bool,
        openedWindowKey: String?,
        yesterdayDecision: YesterdayDecision? = nil,
        filmUsed: Int? = nil,
        calendar: Calendar = .current
    ) -> HomeState {
        let latest = DailyWindow.latest(for: now, calendar: calendar)
        let shotsInLatest = myCaptureDates.filter { $0 >= latest.open && $0 < latest.close && $0 <= now }
        let shotInLatest = shotsInLatest.max()

        if DailyWindow.isNight(now, calendar: calendar) {
            // 夜(00:00〜09:00):直近の窓(前日9:00〜当日0:00)に撮ったか。
            return shotInLatest != nil ? .night : .rest
        }

        // 昼(9:00〜24:00):今の窓に撮ったか。
        if let shotInLatest {
            // 決める順番:自分の1枚 → みんなの昨日
            if yesterdayDecision == .undecided { return .deciding(shotAt: shotInLatest) }
            let opened = openedWindowKey == DailyWindow.key(for: now, calendar: calendar)
            guard opened else { return .ready(shotAt: shotInLatest) }
            // ひらいたあと、3こま目まで残りがあれば、また撮れる
            // 数えるのは FilmCounter(filmUsed)。渡されなければ保存ずみの写真から(テスト・プレビュー用)
            let remaining = FilmRoll.shotsRemaining(shotsToday: max(filmUsed ?? 0, FilmRoll.distinctShotCount(shotsInLatest)))
            return remaining > 0 ? .more(shotAt: shotInLatest, remaining: remaining) : .opened(shotAt: shotInLatest)
        }

        let hasAnyPastPhotos = hasDeposited || myCaptureDates.contains { $0 < latest.open }
        return hasAnyPastPhotos ? .dawn : .first
    }

    /// 「昨日」の窓(ひらく対象)で、指定のグループに投稿された写真の枚数(自分の分も含む)。同じ人の1枚は
    /// グループごとに別レコードとして保存されるため、撮影者と撮影時刻で重複を除く。
    /// 画像には触れず、件数だけを数える。
    static func yesterdayPhotoCount(in groups: [LaterGroup], now: Date, calendar: Calendar = .current) -> Int {
        let window = DailyWindow.yesterday(for: now, calendar: calendar)
        var seen = Set<String>()
        for group in groups {
            for photo in group.photos where photo.isPosted && photo.captureDate >= window.open && photo.captureDate < window.close {
                seen.insert(photo.dedupeKey)
            }
        }
        return seen.count
    }
}

extension LaterPhoto {
    /// グループごとに複製された同じ1枚を、1枚として数えるためのキー(撮影者+撮影時刻)。
    var dedupeKey: String {
        let author = authorCloudKitUserRecordName ?? owner?.id.uuidString ?? id.uuidString
        return "\(author)|\(captureDate.timeIntervalSinceReferenceDate)"
    }
}

// MARK: - 撮れる時間(窓)

/// 撮れる時間「窓」= 9:00〜24:00。00:00〜09:00は夜(次の窓の前)。
/// 「直近の窓」は、昼ならその日の窓、夜なら前の日の窓。日付ではなく窓を単位にすることで、
/// 「撮ったか」「ひらいたか」が9:00ちょうどで切り替わる。
enum DailyWindow {
    /// 夜(00:00〜09:00)か
    static func isNight(_ now: Date, calendar: Calendar = .current) -> Bool {
        now < DailyExposureRules.window(for: now, calendar: calendar).open
    }

    /// 直近の窓(昼:今日の9:00〜24:00、夜:前日の9:00〜24:00)
    static func latest(for now: Date, calendar: Calendar = .current) -> (open: Date, close: Date) {
        let today = DailyExposureRules.window(for: now, calendar: calendar)
        guard isNight(now, calendar: calendar) else { return today }
        let previousDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
        return DailyExposureRules.window(for: previousDay, calendar: calendar)
    }

    /// 「ひらく」対象の昨日の窓(昼:前日の窓、夜:前々日の窓。夜は撮れないため参照しない想定)
    static func yesterday(for now: Date, calendar: Calendar = .current) -> (open: Date, close: Date) {
        let latest = latest(for: now, calendar: calendar)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: latest.open) ?? latest.open
        return DailyExposureRules.window(for: previousDay, calendar: calendar)
    }

    /// 直近の窓を表すキー(窓がひらいた日の「yyyy-MM-dd」)
    static func key(for now: Date, calendar: Calendar = .current) -> String {
        LaterDay.key(for: now, calendar: calendar)
    }

    /// 時間のカプセル:昼は24:00(消灯)まで、夜は9:00(ひらく)までの残り分(秒は切り捨て。
    /// 9:06:20なら「14:53」)。
    static func capsule(now: Date, calendar: Calendar = .current) -> (isNight: Bool, minutes: Int) {
        let today = DailyExposureRules.window(for: now, calendar: calendar)
        let target = now < today.open ? today.open : today.close
        return (now < today.open, max(0, Int(target.timeIntervalSince(now) / 60)))
    }

    /// 「消灯まで 14:54」「ひらくまで 03:12」
    static func capsuleText(now: Date, calendar: Calendar = .current) -> String {
        let parts = capsuleParts(now: now, calendar: calendar)
        return "\(parts.label) \(parts.time)"
    }

    /// カプセルの言葉と時刻(数字だけ等幅で描くため、分けて返す)
    static func capsuleParts(now: Date, calendar: Calendar = .current) -> (label: String, time: String) {
        let c = capsule(now: now, calendar: calendar)
        let time = String(format: "%02d:%02d", c.minutes / 60, c.minutes % 60)
        return (c.isNight ? "ひらくまで" : "消灯まで", time)
    }
}

// MARK: - 昨日の光(件数)

/// 昨日の光の数。取得できていない・失敗を「0」にしない。
enum YesterdayLight: Equatable {
    case loading
    case failed
    case count(Int)

    var value: Int? {
        if case .count(let n) = self { return n }
        return nil
    }
}

// MARK: - 月の出し方

extension HomeState {
    /// 月の種類。ready でも、ひらく昨日が1枚もない(初日に撮った直後など)なら、月はロックする。
    enum MoonPlan: Hashable {
        case locked(title: String, subtitle: String)
        case shoot
        /// 昨日の自分の1枚を選ぶ(タップで「投稿するか選ぶ」へ)
        case decide
        case open
        case review
    }

    func moonPlan(yesterday: YesterdayLight) -> MoonPlan {
        switch self {
        case .night, .rest:
            return .locked(title: "9:00に、ひらきます", subtitle: "いまは、おやすみの時間")
        case .dawn, .first, .more:
            return .shoot
        case .deciding:
            return .decide
        case .ready:
            if yesterday == .count(0) {
                return .locked(title: "あしたの朝に、ひらきます", subtitle: "今日の1枚が、最初の昨日になる")
            }
            return .open
        case .opened:
            return .review
        }
    }
}

// MARK: - 現像(預けた1枚が、濃くなって色づく)

/// 撮った時刻t0から、次の9:00(t1)までを0〜100%とする。濃さは p = t^1.6
/// (最初はゆっくり、朝にむけて一気に)。次の9:00を過ぎたら100%で止まる。
/// 見た目だけの進行で、解禁の判定には使わない。
enum DevelopProgress {
    static let exponent = 1.6

    static func progress(capturedAt t0: Date, now: Date) -> Double {
        let t1 = finishDate(capturedAt: t0)
        let span = t1.timeIntervalSince(t0)
        guard span > 0 else { return 1 }
        let t = min(1, max(0, now.timeIntervalSince(t0) / span))
        return pow(t, exponent)
    }

    /// 撮った時刻から見た「次の9:00」
    static func finishDate(capturedAt t0: Date, calendar: Calendar = .current) -> Date {
        let todayOpening = calendar.date(bySettingHour: DailyExposureRules.openingHour, minute: 0, second: 0, of: t0) ?? t0
        if t0 < todayOpening { return todayOpening }
        return calendar.date(byAdding: .day, value: 1, to: todayOpening) ?? todayOpening
    }

    /// 進行の色:#3A3A3D → #FF9E5E を p^0.8 で混ぜる(濃くなるほど、オレンジに)。
    static func trackColor(_ p: Double) -> Color {
        let m = pow(max(0, min(1, p)), 0.8)
        return Color(
            red: (0x3A + (0xFF - 0x3A) * m) / 255,
            green: (0x3A + (0x9E - 0x3A) * m) / 255,
            blue: (0x3D + (0x5E - 0x3D) * m) / 255
        )
    }

    /// 写真の色が取れない時の既定の3色(オレンジ・青・黄)
    static let defaultTones: [Color] = [HomePalette.orange, HomePalette.blue, HomePalette.yellow]

    /// 濃さpに応じて、色を暗く・くすませる(saturate(p)・brightness(0.16 + 0.84p))。
    static func developed(_ color: Color, _ p: Double) -> Color {
        let ui = UIColor(color)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        ui.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: hue, saturation: saturation * p, brightness: brightness * (0.16 + 0.84 * p))
    }
}

/// 現像カードに出す1枚(写真そのものではなく、色と時刻だけ)。
struct DevelopSubject: Equatable {
    enum Kind: Equatable {
        /// 昨日の1枚(①②)
        case yesterday
        /// 今日の1枚(③・③')
        case today
        /// お休み明けで待っている1枚(④)、または9:00前に昨日より前の1枚が待っている
        case waiting(Date)
    }

    let kind: Kind
    let capturedAt: Date
    let tones: [Color]
}

// MARK: - データ

/// 今日撮った1枚(本物の写真データは持たない。時刻と街だけ)
struct TodayShot: Identifiable, Equatable {
    let id: String
    let takenAt: Date
    let city: String?
}

enum TodayFilmRules {
    /// 1日のコマ数
    static var frameCount: Int { FilmRoll.shotsPerDay }

    enum Frame: Equatable, Identifiable {
        /// 撮った(index は 0 から)
        case shot(TodayShot, index: Int)
        /// 次に撮る枠(オレンジの点線「＋ 撮る」)
        case next(index: Int)
        /// その先の枠(白い点線「あとで」)
        case later(index: Int)

        var id: String {
            switch self {
            case .shot(let shot, _): return "shot-\(shot.id)"
            case .next(let i): return "next-\(i)"
            case .later(let i): return "later-\(i)"
            }
        }
    }

    /// 3つの枠。撮った分 → 次の1枠 → のこりは「あとで」。撮れない時間なら「次」はなし
    static func frames(shots: [TodayShot], canShoot: Bool) -> [Frame] {
        let taken = Array(shots.sorted { $0.takenAt < $1.takenAt }.prefix(frameCount))
        var result: [Frame] = taken.enumerated().map { .shot($1, index: $0) }
        for index in taken.count..<frameCount {
            result.append(index == taken.count && canShoot ? .next(index: index) : .later(index: index))
        }
        return result
    }

    /// 枠の傾き(-3° / 0° / +3°)
    static func tilt(index: Int) -> Double { [-3, 0, 3][min(max(index, 0), 2)] }

    /// つぎの 9:00(今日の写真がひらく時刻)
    static func nextRevealDate(after now: Date, calendar: Calendar = .current) -> Date {
        PhotoDevelop.developDate(takenAt: now, calendar: calendar)
    }

    /// 「あと 16時間 30分」(分は切り上げ:0分にならない)
    static func remaining(now: Date, calendar: Calendar = .current) -> (hours: Int, minutes: Int) {
        let seconds = max(0, nextRevealDate(after: now, calendar: calendar).timeIntervalSince(now))
        let minutes = Int((seconds / 60).rounded(.up))
        return (minutes / 60, minutes % 60)
    }

    static func remainingText(now: Date, calendar: Calendar = .current) -> String {
        let r = remaining(now: now, calendar: calendar)
        return r.hours > 0 ? "あと \(r.hours)時間 \(r.minutes)分" : "あと \(r.minutes)分"
    }

    /// 朝焼けアーチの太陽:最初に撮った時刻 → つぎの 9:00 までの進み(0〜1)。撮っていなければ nil
    static func archProgress(shots: [TodayShot], now: Date, calendar: Calendar = .current) -> Double? {
        guard let first = shots.map(\.takenAt).min() else { return nil }
        let reveal = PhotoDevelop.developDate(takenAt: first, calendar: calendar)
        let total = reveal.timeIntervalSince(first)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(first) / total))
    }

    /// 月のことば:0枚「今日を 撮る」/ 1〜2枚「もう 1枚 撮る」/ 3枚「今日は おしまい」
    static func moonTitle(shots: Int) -> String {
        switch shots {
        case ..<1: return "今日を 撮る"
        case frameCount...: return "今日は、ここまで"
        default: return "もう 1枚 撮る"
        }
    }

    static func moonSubtitle(shots: Int) -> String {
        let left = max(0, frameCount - shots)
        return left == 0 ? "あしたの 9:00 に ひらく" : "のこり \(left)こま"
    }

    /// 撮った時刻「23:41」
    static func timeText(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

