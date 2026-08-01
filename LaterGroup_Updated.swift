import Foundation
import SwiftUI
import SwiftData

/// グループ（Circle）のデータモデル
@Model
class LaterGroup {
    var id: UUID = UUID()
    var name: String
    var creationDate: Date
    var inviteCode: String = "" // グループ招待コード
    
    // 🌟 グループに参加しているユーザーたち
    @Relationship(inverse: \UserProfile.groups)
    var members: [UserProfile] = []
    
    // 🌟 グループで共有されている写真たち
    @Relationship(deleteRule: .cascade)
    var photos: [LaterPhoto] = []
    
    // 🏆 ホスト管理
    @Relationship
    var host: UserProfile?
    
    // 🎯 グループ設定
    var autoGenerateMission: Bool = false // ミッション自動生成
    var isPrivate: Bool = true // プライバシー設定（true: 招待のみ, false: 検索可能）
    var currentDailyMission: String? // 今日のミッション
    var missionGeneratedDate: Date? // ミッション生成日
    
    private static func generateGroupCode(length: Int = 6) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    init(name: String, host: UserProfile? = nil, autoGenerateMission: Bool = false, isPrivate: Bool = true) {
        self.id = UUID()
        self.name = name
        self.creationDate = Date()
        self.host = host
        self.inviteCode = Self.generateGroupCode()
        self.autoGenerateMission = autoGenerateMission
        self.isPrivate = isPrivate
    }
}

// MARK: - グループメンバー管理の拡張

extension LaterGroup {
    /// メンバーがグループに所属しているかチェック
    func isMember(userID: UUID) -> Bool {
        members.contains(where: { $0.id == userID })
    }
    
    /// メンバーを追加（重複チェック付き）
    func addMember(_ user: UserProfile) -> Bool {
        guard !isMember(userID: user.id) else {
            return false // すでにメンバー
        }
        members.append(user)
        return true
    }
    
    /// メンバーを削除
    func removeMember(userID: UUID) -> Bool {
        guard let index = members.firstIndex(where: { $0.id == userID }) else {
            return false // メンバーが見つからない
        }
        members.remove(at: index)
        return true
    }
    
    /// ホストかどうかをチェック
    func isHost(userID: UUID) -> Bool {
        return host?.id == userID
    }
}

// MARK: - グループ写真管理の拡張

extension LaterGroup {
    /// 今日撮影された写真を取得
    func getTodayPhotos() -> [LaterPhoto] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return photos.filter { photo in
            calendar.isDate(photo.captureDate, inSameDayAs: today)
        }
    }
    
    /// 特定の日のベストショットを取得
    func getBestShot(for date: Date) -> LaterPhoto? {
        let calendar = Calendar.current
        
        return photos.first { photo in
            photo.isGroupBestShot && calendar.isDate(photo.captureDate, inSameDayAs: date)
        }
    }
    
    /// アンロック済みの写真のみを取得
    func getUnlockedPhotos() -> [LaterPhoto] {
        photos.filter { $0.isUnlocked }
    }
    
    /// 投票中の写真を取得
    func getVotingPhotos() -> [LaterPhoto] {
        photos.filter { $0.votingPhaseActive }
    }
}

// MARK: - グループ統計の拡張

extension LaterGroup {
    /// グループの活動日数
    var activeDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(photos.map { calendar.startOfDay(for: $0.captureDate) })
        return uniqueDays.count
    }
    
    /// 総写真数
    var totalPhotos: Int {
        photos.count
    }
    
    /// メンバー数
    var memberCount: Int {
        members.count
    }
    
    /// グループの年齢（作成からの日数）
    var ageInDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: creationDate, to: Date())
        return components.day ?? 0
    }
}

// MARK: - グループバリデーション

extension LaterGroup {
    /// グループ名が有効かチェック
    var isValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 招待コードが有効かチェック
    var isValidInviteCode: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// グループが有効かチェック
    var isValid: Bool {
        isValidName && !members.isEmpty
    }
}
