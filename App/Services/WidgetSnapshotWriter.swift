import Foundation
import UIKit
import CoreImage
import CloudKit
import WidgetKit
import Observation

/// v96:アプリの 今の 値から WidgetSnapshot を 作り、App Group に 書く(+ 小さな 画像)。
///
/// 写真の ルール(PROMPT_v96 §5):
/// - きのうの 友だちの 本物の 写真(300px)は **自分が 今日 1枚 撮った 時 だけ** 書く。それ以外は 消す。
/// - 今日の 友だちの 写真(9:00 に ひらく 分)は 本物を 書かない。数 ・ タグ ・ 名前 と、
///   もとから ぼかし済みの モザイク(mosaicTiny)を もう1回 ぼかした 画像 だけ。
/// - 画像は 表示の 2倍 まで(サムネ 300px ・ ぼかし ・ アイコン 120px)。
@MainActor
enum WidgetSnapshotWriter {
    struct Input {
        var now: Date
        var shots: Int
        var limit: Int
        var me: UserProfile?
        var myRecordName: String?
        var friends: [HomeFriend]
        /// 共有 グループ(個人の スペースを のぞく)
        var groups: [LaterGroup]
    }

    /// 最後に 書いた 中身(同じ なら 書かない ・ reload しない)
    private static var lastSignature = ""
    private static let photoCap = 5

    private static var fontsInstalled = false

    static func write(_ input: Input, calendar: Calendar = .current) {
        if !fontsInstalled {
            fontsInstalled = true
            Task.detached(priority: .background) { WidgetSharedFonts.install() }
        }
        let now = input.now
        let dayStart = LaterDay.start(of: now, calendar: calendar)
        let prevStart = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
        let dayKey = LaterDay.key(for: now, calendar: calendar)
        let myID = input.me?.id
        let friendIDs = Set(input.friends.filter { !$0.isMe }.map(\.id))

        func isMine(_ p: LaterPhoto) -> Bool {
            if let r = input.myRecordName, p.authorCloudKitUserRecordName == r { return true }
            if let myID, p.owner?.id == myID { return true }
            return false
        }
        func author(_ p: LaterPhoto) -> String? { p.authorCloudKitUserRecordName ?? p.owner?.cloudKitUserRecordName ?? p.owner?.id.uuidString }

        // 友だちの 写真(同じ 1枚は 1つ)を 日ごとに
        var seen = Set<String>()
        var todayPhotos: [LaterPhoto] = []
        var prevPhotos: [LaterPhoto] = []
        for g in input.groups {
            for p in g.photos where p.captureDate >= prevStart && p.captureDate <= now && !isMine(p) {
                guard let a = author(p), friendIDs.contains(a), seen.insert(p.dedupeKey).inserted else { continue }
                if p.captureDate >= dayStart { todayPhotos.append(p) } else if p.isPosted { prevPhotos.append(p) }
            }
        }
        todayPhotos.sort { $0.captureDate < $1.captureDate }
        prevPhotos.sort { $0.captureDate < $1.captureDate }

        func summary(_ list: [LaterPhoto], key: String) -> DaySummary? {
            guard !list.isEmpty else { return nil }
            var names: [String] = []
            for p in list {
                let n = p.authorNameCache ?? p.owner?.name ?? "だれか"
                if !names.contains(n) { names.append(n) }
            }
            let tags = Dictionary(grouping: list.compactMap(\.tags.first), by: { $0 }).max { $0.value.count < $1.value.count }?.key
            return DaySummary(dayKey: key, people: names.count, count: list.count, tag: tags, names: Array(names.prefix(5)))
        }

        // 今日の 自分の こま(時刻 ・ ぼかし)
        var mine: [LaterPhoto] = []
        var mineSeen = Set<String>()
        for p in (input.me?.photos ?? []).sorted(by: { $0.captureDate < $1.captureDate }) where p.captureDate >= dayStart && p.captureDate <= now {
            if mineSeen.insert(p.dedupeKey).inserted { mine.append(p) }
        }
        let shots = max(input.shots, mine.count)

        // 画像の 仕事(データだけ 先に 集める。重い 処理は うしろで)
        var jobs: [ImageJob] = []
        let df = DateFormatter(); df.dateFormat = "H:mm"

        let shotBlurs: [String] = mine.prefix(input.limit).compactMap { p in
            let name = "s_\(stableHash(p.dedupeKey)).jpg"
            jobs.append(.init(name: name, data: p.imageData, kind: .blur(120)))
            return name
        }

        // きのうの 本物の 写真:今日 1枚 撮った 時 だけ
        var yPhotos: [YPhoto] = []
        if shots > 0 {
            for p in prevPhotos.suffix(photoCap) where !p.imageData.isEmpty {
                let name = "y_\(stableHash(p.dedupeKey)).jpg"
                jobs.append(.init(name: name, data: p.imageData, kind: .thumb(300)))
                yPhotos.append(YPhoto(uid: author(p) ?? "", name: p.authorNameCache ?? p.owner?.name ?? "だれか", time: df.string(from: p.captureDate), tag: p.tags.first, thumb: name))
            }
        }

        // ロック中の 絵:モザイク(もとから ぼかし済み)を もう1回 ぼかす
        let lockSource = shots > 0 ? todayPhotos : (prevPhotos.isEmpty ? todayPhotos : prevPhotos)
        let locked: [String] = lockSource.suffix(photoCap).compactMap { p in
            guard let tiny = p.mosaicTiny, !tiny.isEmpty else { return nil }
            let name = "l_\(stableHash(p.dedupeKey)).jpg"
            jobs.append(.init(name: name, data: tiny, kind: .blur(120)))
            return name
        }

        // 友だち(今日 撮った こま ・ アイコン ・ つつく の 宛先)
        let counts = HomeV17Rules.shotCounts(groups: input.groups, now: now, calendar: calendar)
        let groupsByID = Dictionary(input.groups.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let rings: [FriendRing] = input.friends.filter { !$0.isMe }.prefix(8).map { f in
            var avatar: String?
            if let data = f.avatarData, !data.isEmpty {
                let name = "a_\(stableHash(f.id + "#\(data.count)")).jpg"
                jobs.append(.init(name: name, data: data, kind: .thumb(120)))
                avatar = name
            }
            let knock = f.groupIDs.lazy.compactMap { groupsByID[$0] }.compactMap(Self.knockTarget(for:)).first
            let shot = counts[f.id] ?? (f.hasShot ? 1 : 0)
            return FriendRing(uid: f.id, name: f.name, initial: String(f.name.prefix(1)), colorHex: Self.color(for: f.id), shotsToday: min(3, shot), avatar: avatar, knock: knock)
        }

        // Trip(いちばん 新しい グループ。Home の Trip と 同じ 決め方)
        var trip: TripSnap?
        if let g = input.groups.sorted(by: { $0.creationDate > $1.creationDate }).first {
            let todays = g.photos.filter { calendar.isDate($0.captureDate, inSameDayAs: now) }.sorted { $0.captureDate < $1.captureDate }
            let total = 23
            let day = (calendar.dateComponents([.day], from: calendar.startOfDay(for: g.creationDate), to: calendar.startOfDay(for: now)).day ?? 0) + 1
            let sd = DateFormatter(); sd.locale = Locale(identifier: "en_US_POSIX"); sd.dateFormat = "MM/dd EEE"
            var cover: String?
            if let data = g.iconImageData, !data.isEmpty {
                cover = "t_\(stableHash(g.id.uuidString + "#\(data.count)")).jpg"
                jobs.append(.init(name: cover!, data: data, kind: .thumb(240)))
            }
            trip = TripSnap(id: g.id.uuidString, title: g.name, sub: "\(sd.string(from: now).uppercased()) ・ \(g.members.count)人", day: day, count: min(total, todays.count), total: total, passNo: Self.passNumber(g.name), filled: Array(0..<min(total, todays.count)), cover: cover)
        }

        let mondo = WorldWordsStore.entries(now: now)
        let world = WorldCountStore.shared
        let snapshot = WidgetSnapshot(
            dayKey: dayKey,
            writtenAt: now,
            shots: min(shots, input.limit),
            limit: input.limit,
            shotTimes: mine.map(\.captureDate),
            shotBlurs: shotBlurs,
            friends: rings,
            today: summary(todayPhotos, key: dayKey),
            yesterday: summary(prevPhotos, key: LaterDay.key(for: prevStart, calendar: calendar)),
            yesterdayPhotos: yPhotos,
            lockedPreviews: locked,
            mondoTag: mondo.words.first.map { "#\($0.tag)" },
            mondoCount: world.count,
            mondoCountries: mondo.countries ?? world.countryCount,
            trip: trip,
            next: nil,
            myRecordName: input.myRecordName,
            myName: input.me?.name ?? ""
        )

        LattagLive.sync(snapshot: snapshot, now: now)
        var sig = snapshot
        sig.writtenAt = .distantPast
        let signature = (try? WidgetSnapshot.encoder().encode(sig)).map { String(decoding: $0, as: UTF8.self) } ?? UUID().uuidString
        guard signature != lastSignature else { return }
        lastSignature = signature

        let keep = Set(jobs.map(\.name))
        Task.detached(priority: .utility) {
            Self.writeImages(jobs, keep: keep)
            snapshot.save()
            await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// 撮った すぐ あと(アプリの 画面を 待たずに こまの 数だけ 先に 反映)
    static func reloadAfterShot() {
        LattagLive.sync(snapshot: WidgetSnapshot.load())
        WidgetCenter.shared.reloadTimelines(ofKind: LattagShared.Kind.lens)
        WidgetCenter.shared.reloadTimelines(ofKind: LattagShared.Kind.until9)
        WidgetCenter.shared.reloadTimelines(ofKind: LattagShared.Kind.lockRing)
        WidgetCenter.shared.reloadTimelines(ofKind: LattagShared.Kind.lockRect)
        WidgetCenter.shared.reloadTimelines(ofKind: LattagShared.Kind.lockInline)
    }

    // MARK: - 小物

    /// 友だちの 色(起動ごとに 変わらない ように 名前の ハッシュで 選ぶ。Home と 同じ 7色)
    static func color(for id: String) -> String {
        let palette = ["61DD7A", "7FB0FF", "EE5E9C", "C8F25A", "B28CFF", "5AC8FF", "FFD25A"]
        return palette[Int(stableHash(id) % UInt64(palette.count))]
    }

    /// TRIP PASS の 番号(TripNewV83View と 同じ 計算)
    static func passNumber(_ name: String) -> Int {
        name.isEmpty ? 1074 : name.unicodeScalars.reduce(1074) { ($0 &* 31 &+ Int($1.value)) % 10000 }
    }

    static func knockTarget(for group: LaterGroup) -> KnockTarget? {
        guard let t = LayerCloud.target(for: group) else { return nil }
        let shared = t.database.databaseScope == .shared
        return KnockTarget(zoneName: t.zoneID.zoneName, zoneOwner: t.zoneID.ownerName, shared: shared, parentRecordName: t.parent?.recordName)
    }

    /// 起動ごとに 変わらない ハッシュ(FNV-1a)
    nonisolated static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
        return h
    }

    // MARK: - 画像

    struct ImageJob: Sendable {
        enum Kind: Sendable { case thumb(CGFloat), blur(CGFloat) }
        let name: String
        let data: Data
        let kind: Kind
    }

    nonisolated private static func writeImages(_ jobs: [ImageJob], keep: Set<String>) {
        guard let dir = LattagShared.imageDir else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // 使わなく なった 画像は 消す(ルールが かわった 時 = 本物の 写真が 残らない)
        for f in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where !keep.contains(f) {
            try? fm.removeItem(at: dir.appendingPathComponent(f))
        }
        let ctx = CIContext()
        for job in jobs {
            let url = dir.appendingPathComponent(job.name)
            if fm.fileExists(atPath: url.path) { continue }
            let out: Data?
            switch job.kind {
            case .thumb(let px):
                out = PhotoColor.thumbnailData(fromData: job.data, maxDimension: px)
            case .blur(let px):
                out = blurred(job.data, maxPixel: px, context: ctx)
            }
            if let out { try? out.write(to: url, options: .atomic) }
        }
    }

    /// 小さく して 1回 だけ ぼかす
    nonisolated private static func blurred(_ data: Data, maxPixel: CGFloat, context: CIContext) -> Data? {
        guard let small = PhotoColor.thumbnailData(fromData: data, maxDimension: maxPixel).flatMap(UIImage.init(data:)) ?? UIImage(data: data),
              let ci0 = CIImage(image: small), let f = CIFilter(name: "CIGaussianBlur") else { return nil }
        f.setValue(ci0.clampedToExtent(), forKey: kCIInputImageKey)
        f.setValue(max(small.size.width, small.size.height) * 0.06, forKey: kCIInputRadiusKey)
        guard let o = f.outputImage, let cg = context.createCGImage(o, from: ci0.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.7)
    }
}

// MARK: - ウィジェットからの 行き先(lattag://shoot ・ develop ・ friends ・ yesterday?f= ・ mondo ・ trip/<id>)

/// ウィジェットを 押して ひらいた 行き先。Home(HomeV64Host)が 出たら 受けとって ひらく(起動 直後でも 消えない)。
@MainActor
@Observable
final class WidgetRouteStore {
    static let shared = WidgetRouteStore()

    enum Route: Equatable {
        case shoot, develop, friends, mondo
        case yesterday(friend: String?)
        case trip(String)
    }

    var pending: Route?

    nonisolated static func route(from url: URL) -> Route? {
        guard Brand.isOurScheme(url) else { return nil }
        switch url.host?.lowercased() {
        case "shoot": return .shoot
        case "develop": return .develop
        case "friends": return .friends
        case "mondo": return .mondo
        case "yesterday":
            let f = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "f" }?.value
            return .yesterday(friend: f)
        case "trip":
            let id = url.pathComponents.dropFirst().first ?? ""
            return id.isEmpty ? .friends : .trip(id)
        default: return nil
        }
    }

    /// 受けとる(1回 だけ)
    func take() -> Route? {
        defer { pending = nil }
        return pending
    }
}
