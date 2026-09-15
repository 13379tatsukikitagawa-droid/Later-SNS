import Foundation
import SwiftData

/// 「今日のLater」選択1件のローカル記録。World Laterで見た投稿の中から1枚選び、
/// 理由タグを添えて確定した結果を保持する。1日1回までで、選んだ投稿の作者には
/// 「選ばれた」という結果(Tomorrow +1)だけが伝わり、誰が選んだかは伝わらない
/// (評価対象は「人」ではなく「瞬間」)。
///
/// 集計(自分の投稿が今日何回選ばれたか)はサーバー(この場合はCloudKitのクエリ結果)
/// 側でのみ行い、他ユーザーの選択内容をこの端末が個別に読み取ることはない
/// (WorldLaterService.fetchSelectionCount参照)。
@Model
final class TodaysLaterSelection {
    @Attribute(.unique) var id: UUID = UUID()
    /// 選んだ対象のWorldPost.id(CKRecord.recordNameと同じ文字列表現)。
    var targetPostRecordName: String
    var reasonTag: String
    /// 選択が確定した瞬間(1日1回の判定に使う、暦日単位)。
    var selectedDate: Date
    var createdAt: Date = Date()

    // CloudKit同期メタデータ(Public DB、WorldLaterService参照)
    var ckRecordName: String?

    init(targetPostRecordName: String, reasonTag: String, selectedDate: Date = Date()) {
        self.targetPostRecordName = targetPostRecordName
        self.reasonTag = reasonTag
        self.selectedDate = selectedDate
    }
}

/// Today's Laterで選ぶ際の理由タグ。「なぜこの瞬間が良かったか」を一言で添える
/// (評価対象を「人」ではなく「瞬間」にするための設計上の配慮)。
enum TodaysLaterReasonTag: String, CaseIterable, Identifiable {
    case beautiful = "きれいだった"
    case funny = "おもしろかった"
    case relatable = "共感した"
    case peaceful = "落ち着いた"
    case surprising = "意外だった"
    case warm = "あたたかい気持ちになった"

    var id: String { rawValue }
}
