import SwiftUI
import SwiftData
import Foundation

// MARK: - SwiftData Models

@Model
class LaterPhoto {
    var id: UUID
    var imageData: Data
    var captureDate: Date
    var unlockDate: Date
    var isUnlocked: Bool
    var votingPhaseActive: Bool
    var owner: UserProfile?
    
    init(imageData: Data, captureDate: Date, unlockDate: Date, owner: UserProfile? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.captureDate = captureDate
        self.unlockDate = unlockDate
        self.isUnlocked = false
        self.votingPhaseActive = false
        self.owner = owner
    }
    
    var remainingTimeText: String {
        let remaining = unlockDate.timeIntervalSince(Date())
        if remaining <= 0 {
            return "解禁済み"
        }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours)時間\(minutes)分"
    }
}

@Model
class UserProfile {
    var id: UUID
    var username: String
    var dailyGoal: Int
    
    init(username: String = "User", dailyGoal: Int = 5) {
        self.id = UUID()
        self.username = username
        self.dailyGoal = dailyGoal
    }
}

@Model
class LaterGroup {
    var id: UUID
    var name: String
    var createdAt: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
