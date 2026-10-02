import Foundation
import SwiftData

/// 「今日の1枚」の撮影ルール(Later 基本ルール 再設計版 §2・§3)。
/// 実機で調整・変更しやすいよう、数値はすべてここに集める。
enum DailyExposureRules {
    /// 撮影スタートの時刻(全員同時)。
    static let openingHour = 9
    /// 1枚に付けられるタグの上限(「最大3つ」は案。変える時はここだけ直す)。
    static let maxTags = 3
    /// 露光(長押し)に必要な時間。
    static let holdDuration: TimeInterval = 1.5

    /// 撮影を始めてよいか。24:00の判定は「押し始めた時刻」で行うため、呼び出し側は
    /// 長押しを開始した瞬間の時刻を渡す(押している間に24:00を跨いでも有効)。
    /// 9:00より前(=24:00の消灯後も含む)と、今日すでに撮っている場合は始められない。
    static func canBeginExposure(at date: Date, hasShotToday: Bool, calendar: Calendar = .current) -> Bool {
        guard !hasShotToday else { return false }
        return calendar.component(.hour, from: date) >= openingHour
    }

    /// 24:00(消灯)までの残り時間。撮影時間外(9:00より前)はnil。
    static func remainingUntilLightsOut(from now: Date, calendar: Calendar = .current) -> TimeInterval? {
        guard calendar.component(.hour, from: now) >= openingHour,
              let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return nil }
        return midnight.timeIntervalSince(now)
    }

    /// 指定ユーザーが、dateと同じ日にすでに撮影しているか(1日1枚の判定)。
    static func hasShot(on date: Date, by user: UserProfile, calendar: Calendar = .current) -> Bool {
        user.photos.contains { calendar.isDate($0.captureDate, inSameDayAs: date) }
    }

    /// 撮影時に選べる「みんながよく使うタグ」。集計の仕組みができるまでは固定の候補を出す。
    static let suggestedTags = ["朝ごはん", "空", "散歩", "仕事", "カフェ", "夜", "家", "通学", "ひとり", "友だち"]
}

/// 撮った1枚を保存する。プレビューも投稿先選択も挟まず、撮影の瞬間に呼ばれる。
/// 保存先は自分のME(個人スペース)と、参加しているすべてのグループ
/// (「みんな」= 同じグループの人)。CloudKitへの送信は投稿準備画面
/// (PostTargetGroupSelectionView.submitPost)と同じ流れを使う。
@MainActor
enum DailyExposureStore {
    enum SaveError: Error {
        case noDestination
    }

    static func save(
        imageData: Data,
        captureDate: Date,
        tags: [String],
        locationName: String?,
        user: UserProfile,
        groups: [LaterGroup],
        context: ModelContext
    ) throws {
        guard !groups.isEmpty else { throw SaveError.noDestination }

        var inserted: [(photo: LaterPhoto, group: LaterGroup)] = []
        for group in groups {
            // unlockDateは解禁の瞬間にCloudKitManager.evaluateGroupUnlockConditionsが上書きする。
            let photo = LaterPhoto(imageData: imageData, captureDate: captureDate, unlockDate: captureDate, owner: user)
            photo.tags = tags
            photo.authorCloudKitUserRecordName = CloudKitManager.current?.currentUserRecordName
            photo.authorNameCache = user.name
            photo.locationName = locationName
            photo.groupID = group.id
            photo.groupNameCache = group.name
            context.insert(photo)
            group.photos.append(photo)
            inserted.append((photo, group))
        }

        do {
            try context.save()
        } catch {
            for (photo, _) in inserted { context.delete(photo) }
            throw error
        }

        guard let cloudKitManager = CloudKitManager.current else { return }
        Task {
            for (photo, group) in inserted {
                await cloudKitManager.markForUpload(photo: photo, in: group)
                cloudKitManager.markGroupDirty(group.id)
            }
            await cloudKitManager.evaluateGroupUnlockConditions()
            await cloudKitManager.sendPendingChangesNow()
        }
    }
}
