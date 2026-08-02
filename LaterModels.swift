import Foundation
import SwiftUI
import SwiftData

// MARK: - ユーザープロフィール
@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String
    var username: String
    var bio: String = "" // 🌟 一言バイオ（自己紹介）
    var profileImageData: Data?
    var inviteCode: String = ""
    var dailyGoal: Int = 3 // 🌟 目標枚数（初期値3）
    /// Sign in with Appleのユーザー識別子。同じApple IDで再サインインした際に
    /// 同じUserProfileを再利用するためのキー。
    var appleUserID: String?

    // フォロー中のユーザー
    @Relationship
    var following: [UserProfile] = []
    
    // フォロワー（このユーザーをフォローしているユーザー）
    @Relationship
    var followers: [UserProfile] = []
    
    // このユーザーが撮影した写真
    @Relationship(deleteRule: .cascade, inverse: \LaterPhoto.owner)
    var photos: [LaterPhoto] = []
    
    // このユーザーが参加しているグループ
    @Relationship
    var groups: [LaterGroup] = []
    
    private static func generateInviteCode(length: Int = 8) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // avoid ambiguous chars
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    init(name: String, username: String, dailyGoal: Int = 3) {
        self.id = UUID()
        self.name = name
        self.username = username
        self.dailyGoal = dailyGoal
        self.inviteCode = UserProfile.generateInviteCode()
    }
}

// MARK: - 撮影した写真 (思い出の封印データ)
@Model
final class LaterPhoto {
    var id: UUID = UUID()
    var imageData: Data
    var captureDate: Date
    var unlockDate: Date
    var isUnlocked: Bool = false
    
    // 🌟 キャプション（記憶の封印）
    var caption: String?
    
    // 撮影者（所有者）
    @Relationship
    var owner: UserProfile?
    
    // 🏆 グループ投票関連
    var voteCount: Int = 0
    var isGroupBestShot: Bool = false // その日のグループベストに選ばれたか
    var votingClosedAt: Date? // 投票締切時刻
    
    // 🎭 匿名性管理
    var votingPhaseActive: Bool = false // 投票フェーズ中はtrue
    
    init(imageData: Data, captureDate: Date = Date(), unlockDate: Date, owner: UserProfile? = nil, caption: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.captureDate = captureDate
        self.unlockDate = unlockDate
        self.owner = owner
        self.caption = caption
    }
}

// MARK: - 投票記録
@Model
final class PhotoVote {
    var id: UUID = UUID()
    var photo: LaterPhoto?
    var voter: UserProfile?
    var votedAt: Date
    var reactionSpeed: TimeInterval // 解禁からの投票速度（秒）
    
    init(photo: LaterPhoto, voter: UserProfile, reactionSpeed: TimeInterval = 0) {
        self.id = UUID()
        self.photo = photo
        self.voter = voter
        self.votedAt = Date()
        self.reactionSpeed = reactionSpeed
    }
}

// MARK: - グループ（サークル）
// LaterGroup の定義は LaterGroup_Updated.swift に移動されました

