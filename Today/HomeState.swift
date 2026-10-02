import Foundation
import SwiftUI
import UIKit

/// Home画面の状態(再設計 Step 2 + v2)。現在時刻と、自分の撮影日時などだけから決まる。
/// 判定はresolveの1か所にまとめ、現在時刻を外から渡せるようにしている。
enum HomeState: Equatable {
    /// ① 9:00前。opensAtは今日の撮影スタート時刻。
    case beforeOpening(opensAt: Date)
    /// ② 撮れる(9:00〜24:00、今日まだ撮っていない)。
    case canShoot
    /// ③ 撮った後・まだ昨日をひらいていない(長押しでひらく)。shotAtは今日の1枚の撮影時刻。
    case shot(at: Date)
    /// ③' 撮った後・昨日をひらいたあと。
    case opened(at: Date)
    /// ④ お休み明け。②の条件に加えて、自分の「ひらいていない1枚」が昨日より前から待っている。
    case returning(waitingSince: Date)
    /// ⑤ はじめての日(まだ1枚も預けていない)。
    case firstDay
    /// 今日撮らないまま消灯(closingMinute)を過ぎた(仮の表示。本格的なデザインはStep 6)。
    case lightsOut

    /// 撮影できる状態(②・④・⑤)か。
    var canShoot: Bool {
        switch self {
        case .canShoot, .returning, .firstDay: return true
        default: return false
        }
    }

    /// 見出し・ボタンのクロスフェードの単位
    var kind: String {
        switch self {
        case .beforeOpening: return "before"
        case .canShoot: return "canShoot"
        case .shot: return "shot"
        case .opened: return "opened"
        case .returning: return "returning"
        case .firstDay: return "firstDay"
        case .lightsOut: return "lightsOut"
        }
    }
}

/// Homeで扱う時刻。端末のローカル時刻で扱う(タイムゾーンの扱いは未確定のため、定数で変えやすくしておく)。
enum HomeClock {
    /// 撮影スタート(分単位、0:00起点)。撮影画面の判定(DailyExposureRules.openingHour)と同じ値。
    static let openingMinute = DailyExposureRules.openingHour * 60
    /// 消灯(分単位、0:00起点)。24:00 = 1440。24:00のままなら、0:00を過ぎた時点で
    /// 新しい日の「① 9:00前」になるため、lightsOutは消灯を24:00より前に変えた時だけ現れる。
    static let closingMinute = 24 * 60
}

extension HomeState {
    /// - Parameters:
    ///   - now: 現在時刻(テスト・プレビューでは任意の時刻を渡す)
    ///   - myCaptureDates: 自分が撮った写真の撮影日時(グループごとの重複は含んでいてよい)
    ///   - hasDeposited: これまでに1枚でも預けたか(写真が7日で削除された後も、記録から判定する)
    ///   - openedToday: 今日、長押しで昨日をひらいたか
    static func resolve(now: Date, myCaptureDates: [Date], hasDeposited: Bool, openedToday: Bool, calendar: Calendar = .current) -> HomeState {
        let startOfToday = calendar.startOfDay(for: now)
        if let todaysShot = myCaptureDates.filter({ $0 >= startOfToday && $0 <= now }).max() {
            return openedToday ? .opened(at: todaysShot) : .shot(at: todaysShot)
        }

        let minuteOfDay = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        if minuteOfDay < HomeClock.openingMinute {
            let opensAt = calendar.date(byAdding: .minute, value: HomeClock.openingMinute, to: startOfToday) ?? now
            return .beforeOpening(opensAt: opensAt)
        }
        if minuteOfDay >= HomeClock.closingMinute {
            return .lightsOut
        }
        guard hasDeposited || !myCaptureDates.isEmpty else { return .firstDay }

        // 自分の1枚は「次に自分が撮った時」にひらく。最後に撮った日が昨日なら普通の②、
        // それより前(=お休みを挟んだ)なら、その1枚が待っている④になる。日数は数えない。
        if let lastShot = myCaptureDates.filter({ $0 < startOfToday }).max(),
           let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
           lastShot < startOfYesterday {
            return .returning(waitingSince: lastShot)
        }
        return .canShoot
    }

    /// 昨日、指定のグループで撮られた写真の枚数(自分の分も含む)。同じ人の1枚は
    /// グループごとに別レコードとして保存されるため、撮影者と撮影時刻で重複を除く。
    /// 画像には触れず、件数だけを数える。
    static func yesterdayPhotoCount(in groups: [LaterGroup], now: Date, calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else { return 0 }
        var seen = Set<String>()
        for group in groups {
            for photo in group.photos where photo.captureDate >= startOfYesterday && photo.captureDate < startOfToday {
                let author = photo.authorCloudKitUserRecordName ?? photo.owner?.id.uuidString ?? photo.id.uuidString
                seen.insert("\(author)|\(photo.captureDate.timeIntervalSinceReferenceDate)")
            }
        }
        return seen.count
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
