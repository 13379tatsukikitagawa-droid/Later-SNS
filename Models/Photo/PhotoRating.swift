import SwiftUI

// MARK: - Data Models

/// 写真評価データ
struct PhotoRating: Codable, Identifiable {
    let id: UUID
    let photoId: String
    let raterId: String // 評価者のID
    let emoScore: Int // エモ度 (1-3)
    let compositionScore: Int // 構図 (1-3)
    let vibesScore: Int // バイブス (1-3)
    let timestamp: Date
    let customStamp: String? // カスタムスタンプ名（オプション）
    
    init(id: UUID = UUID(), photoId: String, raterId: String, emoScore: Int, compositionScore: Int, vibesScore: Int, customStamp: String? = nil) {
        self.id = id
        self.photoId = photoId
        self.raterId = raterId
        self.emoScore = emoScore
        self.compositionScore = compositionScore
        self.vibesScore = vibesScore
        self.timestamp = Date()
        self.customStamp = customStamp
    }
    
    var totalScore: Double {
        Double(emoScore + compositionScore + vibesScore)
    }
    
    var averageScore: Double {
        totalScore / 3.0
    }
}

/// 評価の集計結果
struct RatingStats {
    let totalRatings: Int
    let averageEmo: Double
    let averageComposition: Double
    let averageVibes: Double
    let customStamps: [String] // 受け取ったカスタムスタンプ
    
    var overallAverage: Double {
        (averageEmo + averageComposition + averageVibes) / 3.0
    }
    
    var rank: String {
        switch overallAverage {
        case 2.7...3.0: return "SSR"
        case 2.3..<2.7: return "SR"
        case 1.7..<2.3: return "R"
        default: return "N"
        }
    }
    
    var rankColor: Color {
        switch rank {
        case "SSR": return .neonPurple
        case "SR": return .neonGold
        case "R": return .neonBlue
        default: return .neonGreen
        }
    }
    
    static func calculate(from ratings: [PhotoRating]) -> RatingStats {
        guard !ratings.isEmpty else {
            return RatingStats(totalRatings: 0, averageEmo: 0, averageComposition: 0, averageVibes: 0, customStamps: [])
        }
        
        let avgEmo = Double(ratings.reduce(0) { $0 + $1.emoScore }) / Double(ratings.count)
        let avgComp = Double(ratings.reduce(0) { $0 + $1.compositionScore }) / Double(ratings.count)
        let avgVibes = Double(ratings.reduce(0) { $0 + $1.vibesScore }) / Double(ratings.count)
        let stamps = ratings.compactMap { $0.customStamp }
        
        return RatingStats(
            totalRatings: ratings.count,
            averageEmo: avgEmo,
            averageComposition: avgComp,
            averageVibes: avgVibes,
            customStamps: stamps
        )
    }
}

