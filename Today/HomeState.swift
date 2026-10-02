import Foundation

/// Home画面の状態(再設計 Step 2)。現在時刻と、自分の撮影日時だけから決まる。
/// 判定はresolve(now:myCaptureDates:)の1か所にまとめ、現在時刻を外から渡せるようにしている。
enum HomeState: Equatable {
    /// ① 9:00前。opensAtは今日の撮影スタート時刻。
    case beforeOpening(opensAt: Date)
    /// ② 撮れる(9:00〜24:00、今日まだ撮っていない)。
    case canShoot
    /// ③ 撮った後。shotAtは今日の1枚の撮影時刻。
    case shot(at: Date)
    /// ④ お休み明け。②の条件に加えて、自分の「ひらいていない1枚」が昨日より前から待っている。
    case returning(waitingSince: Date)
    /// 今日撮らないまま消灯(closingMinute)を過ぎた(仮の表示。本格的なデザインはStep 6)。
    case lightsOut

    /// 撮影できる状態(②・④)か。
    var canShoot: Bool {
        switch self {
        case .canShoot, .returning: return true
        default: return false
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
    static func resolve(now: Date, myCaptureDates: [Date], calendar: Calendar = .current) -> HomeState {
        let startOfToday = calendar.startOfDay(for: now)
        if let todaysShot = myCaptureDates.filter({ $0 >= startOfToday && $0 <= now }).max() {
            return .shot(at: todaysShot)
        }

        let minuteOfDay = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        if minuteOfDay < HomeClock.openingMinute {
            let opensAt = calendar.date(byAdding: .minute, value: HomeClock.openingMinute, to: startOfToday) ?? now
            return .beforeOpening(opensAt: opensAt)
        }
        if minuteOfDay >= HomeClock.closingMinute {
            return .lightsOut
        }

        // 自分の1枚は「次に自分が撮った時」にひらく。最後に撮った日が昨日なら普通の②、
        // それより前(=お休みを挟んだ)なら、その1枚が待っている④になる。日数は数えない。
        if let lastShot = myCaptureDates.filter({ $0 < startOfToday }).max(),
           let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
           lastShot < startOfYesterday {
            return .returning(waitingSince: lastShot)
        }
        return .canShoot
    }

    /// 昨日、参加中のグループで撮られた写真の枚数(自分の分も含む)。同じ人の1枚は
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
