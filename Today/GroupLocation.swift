import CoreLocation
import Foundation
import SwiftData

/// 位置の共有(グループごと・一人ひとり)の、端末の中の記録と保存の処理。
/// 緯度経度は、取った時点で約500mの格子に丸める。正確な GPS は、どこにも持たない。

/// 撮影画面で取れた位置を、丸めた値でだけ、メモリに持つ(MondoPlaceCache と同じ考え方)。
@MainActor
enum ApproxLocationCache {
    static var latest: (latitude: Double, longitude: Double, at: Date)?

    static func set(latitude: Double, longitude: Double, at date: Date = Date()) {
        let cell = LocationRounding.cell(latitude: latitude, longitude: longitude)
        latest = (cell.latitude, cell.longitude, date)
    }

    /// 撮った写真に添えてよい、新しい位置(目安30分以内)
    static func fresh(now: Date = Date()) -> (latitude: Double, longitude: Double)? {
        guard let latest, now.timeIntervalSince(latest.at) <= 30 * 60 else { return nil }
        return (latest.latitude, latest.longitude)
    }
}

/// グループごとのモード(端末の中だけ。初期値はオフ)
enum LocationShareStore {
    private static func key(_ groupID: UUID) -> String { "groupLocationMode.\(groupID.uuidString)" }
    /// 「だれに・どのくらい正確か・いつでも止められる」の確認を見せたか
    static let confirmedKey = "groupLocationConfirmed"

    static func mode(for groupID: UUID, defaults: UserDefaults = .standard) -> GroupLocationMode {
        guard let raw = defaults.string(forKey: key(groupID)), let mode = GroupLocationMode(rawValue: raw) else { return .off }
        // 「いま」を入れない設定のときに、古い値が残っていてもオフとして扱う
        return GroupLocationMode.available.contains(mode) ? mode : .off
    }

    static func setMode(_ mode: GroupLocationMode, for groupID: UUID, defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: key(groupID))
    }

    static var hasConfirmed: Bool {
        get { UserDefaults.standard.bool(forKey: confirmedKey) }
        set { UserDefaults.standard.set(newValue, forKey: confirmedKey) }
    }
}

@MainActor
enum GroupLocationService {
    /// 撮った写真に、丸めた位置を添える。そのグループのモードがオフなら何もしない。
    static func stamp(_ photo: LaterPhoto, groupID: UUID, isPersonalSpace: Bool) {
        guard !isPersonalSpace, LocationShareStore.mode(for: groupID) != .off,
              let cell = ApproxLocationCache.fresh() else { return }
        photo.approxLatitude = cell.latitude
        photo.approxLongitude = cell.longitude
    }

    /// モードを変えたときの後始末。オフにしたら、そのグループの自分の写真の位置を消して、サーバーにも伝える。
    static func didChangeMode(_ mode: GroupLocationMode, group: LaterGroup, user: UserProfile, context: ModelContext) {
        LocationShareStore.setMode(mode, for: group.id)
        guard mode == .off else { return }
        clearStoredLocations(in: group, of: user, context: context)
    }

    static func clearStoredLocations(in group: LaterGroup, of user: UserProfile, context: ModelContext) {
        let mine = group.photos.filter { photo in
            photo.owner?.id == user.id && (photo.approxLatitude != nil || photo.approxLongitude != nil)
        }
        guard !mine.isEmpty else { return }
        for photo in mine {
            photo.approxLatitude = nil
            photo.approxLongitude = nil
        }
        try? context.save()
        guard let manager = CloudKitManager.current else { return }
        Task {
            for photo in mine { await manager.markForUpload(photo: photo, in: group) }
            manager.markGroupDirty(group.id)
            await manager.sendPendingChangesNow()
        }
    }
}

/// 地図に出す「撮った場所」のピン
struct SharedPlacePin: Identifiable, Equatable {
    let id: String
    let latitude: Double
    let longitude: Double
    let authorSeed: UUID
    let isMine: Bool
    let capturedAt: Date
    let tiny: Data?
    let isUnlocked: Bool
}

enum SharedPlacePins {
    /// 昨日・今日の窓の、位置つきの写真から作る。自分がオフのあいだは、他の人の分も出さない(おたがい様)。
    static func pins(
        group: LaterGroup,
        myID: UUID?,
        myMode: GroupLocationMode,
        unlockedKeys: Set<String>,
        now: Date
    ) -> [SharedPlacePin] {
        guard myMode != .off else { return [] }
        let yesterday = DailyWindow.yesterday(for: now)
        let today = DailyWindow.latest(for: now)
        var seen = Set<String>()
        return group.photos.compactMap { photo -> SharedPlacePin? in
            guard let lat = photo.approxLatitude, let lon = photo.approxLongitude,
                  photo.captureDate >= yesterday.open, photo.captureDate < max(today.close, yesterday.close),
                  seen.insert(photo.dedupeKey).inserted else { return nil }
            let isMine = photo.owner?.id == myID
            return SharedPlacePin(
                id: photo.dedupeKey,
                latitude: lat,
                longitude: lon,
                authorSeed: photo.owner?.id ?? photo.id,
                isMine: isMine,
                capturedAt: photo.captureDate,
                tiny: photo.mosaicTiny,
                isUnlocked: isMine || unlockedKeys.contains(photo.dedupeKey)
            )
        }
    }
}
