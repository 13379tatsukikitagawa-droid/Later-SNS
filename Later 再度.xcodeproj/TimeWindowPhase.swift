import Foundation

/// 📅 laterアプリの24時間サイクルにおける現在のフェーズ
enum TimeWindowPhase: String, CaseIterable, Identifiable {
    /// 🌙 0:00 〜 8:00 - 撮影 & キャプション入力フェーズ
    case shooting = "撮影 & キャプション"
    
    /// 🗳️ 8:00 〜 9:00 - 完全匿名・投票フェーズ
    case voting = "完全匿名・投票"
    
    /// 🏆 9:00 〜 23:59 - 結果発表 & カレンダー格納フェーズ
    case results = "結果発表 & カレンダー"
    
    var id: String { rawValue }
    
    /// フェーズの開始時刻（24時間形式）
    var startHour: Int {
        switch self {
        case .shooting: return 0
        case .voting: return 8
        case .results: return 9
        }
    }
    
    /// フェーズの終了時刻（24時間形式、含まない）
    var endHour: Int {
        switch self {
        case .shooting: return 8
        case .voting: return 9
        case .results: return 24
        }
    }
    
    /// フェーズの説明
    var description: String {
        switch self {
        case .shooting:
            return "カメラがアクティブ。目標枚数まで撮影可能。写真は非表示のままキャプション入力へ。"
        case .voting:
            return "カメラはロック。他人の写真に投票可能。投稿者名・キャプションは非表示。"
        case .results:
            return "今日の1位が発表され、全員のカレンダーに格納。自分の写真とキャプションが解禁。"
        }
    }
    
    /// フェーズのアイコン
    var icon: String {
        switch self {
        case .shooting: return "camera.fill"
        case .voting: return "hand.thumbsup.fill"
        case .results: return "calendar"
        }
    }
    
    /// フェーズのテーマカラー（Hex）
    var color: String {
        switch self {
        case .shooting: return "#00ff41" // ネオングリーン
        case .voting: return "#FF6B6B"   // 投票レッド
        case .results: return "#FFD93D"  // ゴールデンイエロー
        }
    }
    
    /// 現在の時刻からフェーズを判定
    /// - Parameter date: 判定する日時（デフォルト: 現在時刻）
    /// - Returns: 該当するフェーズ
    static func current(at date: Date = Date()) -> TimeWindowPhase {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // 0:00 〜 7:59 → 撮影
        if hour >= 0 && hour < 8 {
            return .shooting
        }
        // 8:00 〜 8:59 → 投票
        else if hour >= 8 && hour < 9 {
            return .voting
        }
        // 9:00 〜 23:59 → 結果
        else {
            return .results
        }
    }
    
    /// 次のフェーズまでの残り時間を計算
    /// - Parameter date: 基準となる日時（デフォルト: 現在時刻）
    /// - Returns: 残り時間（秒数）
    func timeUntilNextPhase(from date: Date = Date()) -> TimeInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        
        guard let today = calendar.date(from: DateComponents(year: components.year, month: components.month, day: components.day)) else {
            return 0
        }
        
        // 次のフェーズの開始時刻を計算
        let nextPhaseStartHour: Int
        switch self {
        case .shooting:
            nextPhaseStartHour = 8
        case .voting:
            nextPhaseStartHour = 9
        case .results:
            // 23:59 → 翌日0:00
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                return tomorrow.timeIntervalSince(date)
            }
            return 0
        }
        
        guard let nextPhaseDate = calendar.date(byAdding: .hour, value: nextPhaseStartHour, to: today) else {
            return 0
        }
        
        return max(0, nextPhaseDate.timeIntervalSince(date))
    }
    
    /// 残り時間を「HH:mm:ss」形式で取得
    func formattedTimeUntilNextPhase(from date: Date = Date()) -> String {
        let interval = timeUntilNextPhase(from: date)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
