import Foundation
import SwiftData
import SwiftUI

// 今日のホームの下につづく「層」の中身と、状態ごとの決めごと。
// 画面(HomeLayerViews.swift)はここで作った値を表示するだけ。状態は今の8つ(HomeState)のまま。
// 「撮った」は今の撮影こま数(shotsToday >= 1)で決める。新しいデータは作らない。

// MARK: - 層に出す1つずつ

/// ともだち(丸いアイコン)。撮った人は実線の輪、まだの人は点線の輪。
struct HomeFriend: Identifiable, Equatable {
    /// CloudKit のユーザー名(なければプロフィールの UUID)。ノックの宛先にも使う
    let id: String
    let name: String
    let avatarData: Data?
    let seed: UUID
    /// 直近の窓で撮ったか
    let hasShot: Bool
    /// 市区町村まで(撮った1枚の地名。それより細かい位置は持たない)
    let city: String?
    /// 今日の1枚のモザイク(写真そのものは出さない)
    let mosaicTiny: Data?
    let mosaicKey: String
    let tag: String?
    /// 相手が「ノックを受けない」にしている
    let knockOff: Bool
    let isMe: Bool
    /// ノックを置くグループ(いっしょに入っているグループ)
    let groupIDs: [UUID]
}

/// 昨日のみんな(ポラロイド)。ロック中はモザイクとタグだけ。
struct HomeYesterdayCard: Identifiable, Equatable {
    /// 同じ1枚(グループごとの複製)をまとめるキー。ビューアの1枚の id と同じ
    let id: String
    let groupID: UUID
    /// 灯(👍)の置き場所 = グループの recordName
    let groupRecordName: String?
    let photoRecordName: String
    let authorName: String
    let mosaicTiny: Data?
    let mosaicKey: String
    let tag: String?
    let captureDate: Date
    /// ひらいたあとだけ入る
    let imageData: Data?
    /// v89:その 写真に つけた 1曲(あれば)
    var musicTitle: String? = nil
    var musicArtist: String? = nil
    var musicArtworkURL: String? = nil
    var musicLink: String? = nil
}

/// 7日のフィルムの1こま
struct HomeFilmDay: Identifiable, Equatable {
    enum Kind: Equatable {
        case photo(Data?)
        /// 仕上がる前(撮ったあとの最初の 9:00 まで)
        case developing
        /// 今日まだ撮っていない(点線の「+ きょう撮る」)
        case empty
        /// 撮らなかった日(「おやすみ」。点線の空っぽの枠にしない)
        case rest
    }

    let key: String
    /// 今日からの日数(0が今日)
    let ago: Int
    let date: Date
    let kind: Kind

    var id: String { key }
}

/// 今月のカレンダーで光る日(グループの一枚に選ばれた日)
struct HomeCalendarPick: Equatable, Identifiable {
    let day: String
    let thumbnail: Data?
    var id: String { day }
}

/// 招待のシートで選べるグループ
struct HomeInviteGroup: Equatable, Identifiable {
    let id: UUID
    let name: String
}

/// 層ぜんぶの中身
struct HomeLayerData: Equatable {
    var me: HomeFriend?
    var friends: [HomeFriend] = []
    var yesterday: [HomeYesterdayCard] = []
    var words: [String] = []
    var film: [HomeFilmDay] = []
    var picks: [HomeCalendarPick] = []
    var inviteGroups: [HomeInviteGroup] = []
    /// 窓のキー(ノック・👍の「1日1回」の単位)
    var windowKey: String = ""

    static let empty = HomeLayerData()
}

/// 層からの操作(TodayView がつなぐ)
struct HomeLayerActions {
    var toast: (String) -> Void = { _ in }
    /// 昨日の1枚を、ビューア(そのグループの範囲)で、その写真からひらく
    var openYesterdayPhoto: (_ groupID: UUID, _ itemID: String) -> Void = { _, _ in }
    /// Mondo の「ことばページ」をひらく
    var openWord: (String) -> Void = { _ in }
    /// 撮影をひらく(フィルムの「+ きょう撮る」)
    var shoot: () -> Void = {}
    /// v14 ⑤:ともだち(呼ぶ / グループに えらぶ / とどいた)をひらく
    var openFriends: () -> Void = {}
    /// 招待リンク(グループごと)
    var inviteLink: (UUID) async -> URL? = { _ in nil }
    var createGroup: () -> Void = {}
    /// 👍(灯)を、グループの共有ゾーンへ送る
    var flushThumbs: () async -> Void = {}
}

// MARK: - 状態ごとの決めごと

enum HomeLayerRules {
    /// 昨日のみんなの見せ方
    enum YesterdayMode: Equatable {
        /// 出さない(first)
        case hidden
        /// モザイク + タグだけ。名前は「???」
        case locked
        /// 写真 + 名前 + 👍
        case open
    }

    static func yesterdayMode(_ state: HomeState) -> YesterdayMode {
        switch state {
        case .first: return .hidden
        case .opened, .more: return .open
        case .dawn, .deciding, .ready, .night, .rest: return .locked
        }
    }

    /// ロックをタップしたときの一言(状態ごと)
    static func lockToast(_ state: HomeState) -> String {
        switch state {
        case .dawn, .first: return "今日を撮ると、ひらく"
        case .deciding: return "昨日の1枚を決めると、ひらく"
        case .ready: return "月を長押しすると、ひらく"
        case .night, .rest: return "あした 9:00 に、ひらく"
        case .opened, .more: return ""
        }
    }

    /// ロック中のポラロイドの下に出す言葉。夜は「あした 9:00」、昼はタグ1つ
    static func lockCaption(_ state: HomeState, tag: String?) -> String {
        if state.isNight { return "あした 9:00" }
        guard let tag, !tag.isEmpty else { return "" }
        return "#\(tag)"
    }

    /// ともだちの見出し(夜は「きのう」)
    static func friendsTitle(_ state: HomeState) -> String {
        state.isNight ? "きのう" : "ともだち"
    }

    /// first は「わたし」+「よぶ」だけ
    static func showsFriends(_ state: HomeState) -> Bool {
        state != .first
    }

    /// ともだちの下の一言
    enum FriendStatus: Equatable {
        /// 撮った(色の輪 +「● 撮った」)
        case shot
        /// まだ(今日)
        case notYet
        /// 夜(おやすみ)
        case resting
    }

    static func friendStatus(state: HomeState, friend: HomeFriend) -> FriendStatus {
        if friend.hasShot { return .shot }
        if state.isNight { return .resting }
        return .notYet
    }

    /// ことばをひらけるか(今の玉と同じ考え方:1枚撮ったあと)
    static func wordsUnlocked(state: HomeState, shotsToday: Int) -> Bool {
        shotsToday >= 1 && state.mondoGate == .enter
    }

    static let wordsLockedToast = "1枚撮ると、ことばがひらく"

    /// おわりの文
    static func endLines(_ state: HomeState) -> (title: String, body: String) {
        switch state {
        case .first: return ("ここから、はじまる。", "まず、1枚。それだけで、いい。")
        case .dawn, .deciding, .ready: return ("ここまで。", "つづきは、撮ったあとに。")
        case .opened, .more, .night, .rest: return ("ここまで。", "つづきは、あした 9:00。")
        }
    }

    /// 今日のこま(7日のフィルムの先頭)
    static func filmToday(state: HomeState, shotsToday: Int) -> HomeFilmDay.Kind {
        if shotsToday >= 1 && state != .first { return .developing }
        // まだ撮っていない:撮れるなら「+ きょう撮る」、撮れない時間(夜など)は「おやすみ」
        return state.canShoot ? .empty : .rest
    }

    /// 7日のフィルム:古いコマほど、少しずつうすくなる(今日 1.0 → 6日前 0.5。「消える」ではなく「うすくなる」)
    static func filmOpacity(ago: Int) -> Double {
        max(0.5, 1 - Double(max(0, ago)) * (0.5 / 6))
    }

    /// コマの下のラベル(きょう・きのう・おととい・3日前…)
    static func filmLabel(ago: Int) -> String {
        switch ago {
        case ...0: return "きょう"
        case 1: return "きのう"
        case 2: return "おととい"
        default: return "\(ago)日前"
        }
    }

    /// あと何日のこるか(今日=7日)
    static func filmDaysLeft(ago: Int) -> Int {
        max(0, DailyExposureRules.photoRetentionDays - ago)
    }

    /// 昨日のみんなに使う窓:昼は昨日の窓、夜は 9:00 にひらく直近の窓
    static func yesterdayWindow(state: HomeState, now: Date, calendar: Calendar = .current) -> (open: Date, close: Date) {
        state.isNight ? DailyWindow.latest(for: now, calendar: calendar) : DailyWindow.yesterday(for: now, calendar: calendar)
    }

    /// ポラロイドの数
    static let yesterdayCount = 4
    /// ことば:上位3つ + 流れる2列
    static let topWordCount = 3
}

// MARK: - 組み立て(TodayView から1回だけ呼ぶ)

@MainActor
enum HomeLayerBuilder {
    static func make(
        state: HomeState,
        now: Date,
        shotsToday: Int,
        me: UserProfile?,
        myRecordName: String?,
        groups: [LaterGroup],
        exposureDays: [ExposureDay],
        blocked: Set<String>,
        words: [String],
        picks: [AnnouncedPick],
        calendar: Calendar = .current
    ) -> HomeLayerData {
        var data = HomeLayerData()
        data.windowKey = DailyWindow.key(for: now, calendar: calendar)
        let latest = DailyWindow.latest(for: now, calendar: calendar)

        func isMine(_ photo: LaterPhoto) -> Bool {
            if let myRecordName, photo.authorCloudKitUserRecordName == myRecordName { return true }
            if let me, photo.owner?.id == me.id { return true }
            return false
        }

        // わたし
        if let me {
            data.me = HomeFriend(
                id: myRecordName ?? me.id.uuidString,
                name: "わたし",
                avatarData: me.profileImageData,
                seed: me.id,
                hasShot: shotsToday >= 1,
                city: nil, mosaicTiny: nil, mosaicKey: me.id.uuidString, tag: nil,
                knockOff: me.knockOff,
                isMe: true,
                groupIDs: []
            )
        }

        // ともだち(いっしょのグループの人。同じ人は1人にまとめる)
        var friendOrder: [String] = []
        var friendGroups: [String: [UUID]] = [:]
        var friendProfiles: [String: UserProfile] = [:]
        for group in groups {
            for member in group.members {
                if let me, member.id == me.id { continue }
                if let myRecordName, member.cloudKitUserRecordName == myRecordName { continue }
                if let ck = member.cloudKitUserRecordName, blocked.contains(ck) { continue }
                let key = member.cloudKitUserRecordName ?? member.id.uuidString
                if friendProfiles[key] == nil {
                    friendProfiles[key] = member
                    friendOrder.append(key)
                }
                friendGroups[key, default: []].append(group.id)
            }
        }
        // 直近の窓の、その人の1枚(いちばん新しいもの)
        var latestByAuthor: [String: LaterPhoto] = [:]
        for group in groups {
            for photo in group.photos where photo.captureDate >= latest.open && photo.captureDate < latest.close && !isMine(photo) {
                let key = photo.authorCloudKitUserRecordName ?? photo.owner?.cloudKitUserRecordName ?? photo.owner?.id.uuidString
                guard let key else { continue }
                if let existing = latestByAuthor[key], existing.captureDate >= photo.captureDate { continue }
                latestByAuthor[key] = photo
            }
        }
        data.friends = friendOrder.compactMap { key in
            guard let profile = friendProfiles[key] else { return nil }
            let photo = latestByAuthor[key] ?? latestByAuthor[profile.id.uuidString]
            return HomeFriend(
                id: key,
                name: profile.name.isEmpty ? "だれか" : profile.name,
                avatarData: profile.profileImageData,
                seed: profile.id,
                hasShot: photo != nil,
                city: photo?.locationName.flatMap { $0.isEmpty ? nil : $0 },
                mosaicTiny: photo?.mosaicTiny,
                mosaicKey: photo?.imageCacheKey ?? key,
                tag: photo?.tags.first,
                knockOff: profile.knockOff,
                isMe: false,
                groupIDs: friendGroups[key] ?? []
            )
        }

        // 昨日のみんな(4枚。順位に見えないよう、窓ごとに固定のランダム)
        let mode = HomeLayerRules.yesterdayMode(state)
        if mode != .hidden {
            let window = HomeLayerRules.yesterdayWindow(state: state, now: now, calendar: calendar)
            var seen = Set<String>()
            var cards: [HomeYesterdayCard] = []
            for group in groups {
                for photo in group.photos where photo.captureDate >= window.open && photo.captureDate < window.close {
                    // 昼は投稿した写真だけ(夜は、9:00 にひらく前のモザイクだけを出す)
                    if !state.isNight && !photo.isPosted { continue }
                    if isMine(photo) { continue }
                    if let author = photo.authorCloudKitUserRecordName, blocked.contains(author) { continue }
                    let key = photo.dedupeKey
                    guard seen.insert(key).inserted else { continue }
                    cards.append(HomeYesterdayCard(
                        id: key,
                        groupID: group.id,
                        groupRecordName: group.ckRecordName,
                        photoRecordName: photo.ckRecordName ?? photo.id.uuidString,
                        authorName: photo.authorNameCache ?? photo.owner?.name ?? "だれか",
                        mosaicTiny: photo.mosaicTiny,
                        mosaicKey: photo.imageCacheKey,
                        tag: photo.tags.first,
                        captureDate: photo.captureDate,
                        imageData: mode == .open && !photo.imageData.isEmpty ? photo.imageData : nil,
                        musicTitle: photo.musicTitle, musicArtist: photo.musicArtist, musicArtworkURL: photo.musicArtworkURL, musicLink: photo.musicLink
                    ))
                }
            }
            let seed = ExposureDayStore.dayKey(for: window.open, calendar: calendar)
            data.yesterday = Array(MondoAggregator.seededShuffle(cards.sorted { $0.id < $1.id }, seed: "home-layer-\(seed)").prefix(HomeLayerRules.yesterdayCount))
        }

        data.words = words

        // 7日のフィルム
        let todayStart = calendar.startOfDay(for: latest.open)
        let daysByKey = Dictionary(exposureDays.map { ($0.dayKey, $0) }, uniquingKeysWith: { a, _ in a })
        data.film = (0..<DailyExposureRules.photoRetentionDays).map { ago in
            let date = calendar.date(byAdding: .day, value: -ago, to: todayStart) ?? todayStart
            let key = ExposureDayStore.dayKey(for: date, calendar: calendar)
            let kind: HomeFilmDay.Kind
            if ago == 0 {
                kind = HomeLayerRules.filmToday(state: state, shotsToday: shotsToday)
            } else if let day = daysByKey[key] {
                // 仕上がる前(撮ったあとの最初の 9:00 まで)は、写真を渡さない
                kind = OwnReveal.isOpen(takenAt: day.captureDate, now: now, calendar: calendar) ? .photo(day.thumbnailData) : .developing
            } else {
                kind = .rest
            }
            return HomeFilmDay(key: key, ago: ago, date: date, kind: kind)
        }

        // 今月:グループの一枚に選ばれた日(自分の写真)
        var myNames = Set<String>()
        var bestDays = Set<String>()
        for group in groups {
            for photo in group.photos where isMine(photo) {
                if let name = photo.ckRecordName { myNames.insert(name) }
                if photo.isGroupBestShot { bestDays.insert(ExposureDayStore.dayKey(for: photo.captureDate, calendar: calendar)) }
            }
        }
        for pick in picks where !pick.isWorld && myNames.contains(pick.photoRecordName) {
            bestDays.insert(pick.day)
        }
        data.picks = bestDays.sorted().map { key in
            let day = daysByKey[key]
            let developed = day.map { OwnReveal.isOpen(takenAt: $0.captureDate, now: now, calendar: calendar) } ?? false
            return HomeCalendarPick(day: key, thumbnail: developed ? day?.thumbnailData : nil)
        }

        data.inviteGroups = groups.map { HomeInviteGroup(id: $0.id, name: $0.name) }
        return data
    }
}
