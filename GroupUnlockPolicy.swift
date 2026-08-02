import Foundation

/// グループの早期解禁条件を判定する純粋なロジック。副作用は一切持たない。
/// 実際にisUnlockedを立てたり画像を再送したりする処理は呼び出し側
/// (CloudKitManager/TodayView)が行う。
///
/// このアプリの通常の解禁は写真ごとにランダムな日時(1〜4日後)なので、
/// APP later版のような「共通の解禁締切より前だけ有効」という制限時間の概念は
/// そのままでは当てはまらない。代わりに「今日中」であることだけを制限時間の
/// 条件とし、日付が変わったら通常のランダム解禁に任せる。
enum GroupUnlockPolicy {
    /// グループ全体の目標撮影枚数(固定値)
    static let targetPhotoCount = 5

    static func isEarlyUnlockWindowOpen(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        true
    }

    /// 3条件(今日中・全メンバー撮影済み・目標枚数到達)が揃っているかどうかを判定する。
    static func shouldUnlock(memberIDs: Set<UUID>, todaysPhotoAuthorIDs: [UUID], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEarlyUnlockWindowOpen(now: now, calendar: calendar) else { return false }
        guard !memberIDs.isEmpty else { return false }

        // 条件2: 全メンバーが最低1枚撮影している
        let capturedAuthors = Set(todaysPhotoAuthorIDs)
        guard memberIDs.isSubset(of: capturedAuthors) else { return false }

        // 条件3: グループ全体の目標枚数に到達している
        guard todaysPhotoAuthorIDs.count >= targetPhotoCount else { return false }

        return true
    }
}
