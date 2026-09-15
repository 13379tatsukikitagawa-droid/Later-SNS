import Foundation

/// 撮影時に任意で表示できる「今日のテーマ」。サーバーを持たないアプリの設計方針に
/// 合わせ、あらかじめ用意した候補の中から日付だけで決定論的に1つを選ぶ
/// (GroupUnlockPolicy.stableHashと同じ考え方の軽量ハッシュを使う。全端末が
/// CloudKitへ問い合わせずに同じ「今日のテーマ」を独立に算出できる)。
enum DailyThemeProvider {
    private static let themes: [String] = [
        "今日、空を見上げた瞬間",
        "誰かにありがとうを伝えたくなったもの",
        "何気ない日常の一コマ",
        "今日いちばん笑った瞬間",
        "帰り道で見つけたもの",
        "食べたものの中で一番おいしかったもの",
        "今日出会った色",
        "静かな時間",
        "今日の自分へのご褒美",
        "季節を感じたもの",
        "誰かの後ろ姿",
        "光と影",
        "今日頑張った証拠",
        "小さな発見",
        "明日も見たいと思ったもの",
    ]

    /// 指定した日の「今日のテーマ」。日付だけから決定論的に決まるため、CloudKitへの
    /// 保存・同期は不要(全端末が独立に同じ結果を計算できる)。
    static func theme(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let dayKey = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
        let index = Int(stableHash("theme_\(dayKey)") % UInt64(themes.count))
        return themes[index]
    }

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }
}
