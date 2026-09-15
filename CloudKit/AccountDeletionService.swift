import CloudKit
import Foundation
import SwiftData

/// アカウント削除(App Store審査ガイドライン5.1.1(v)対応)。既存の退出処理
/// (GroupSharingService.leaveGroup)を再利用し、参加中の全グループ(MEを含む)から
/// 退出/削除したのち、Public DBの自分に紐づくレコード(UserDirectory・World Later投稿)を
/// 削除し、最後にローカルのSwiftDataストアを全て消去する。
///
/// 「iCloudアカウント自体」やCloudKitコンテナに残る可能性のあるゴミデータ(例:
/// 既に他メンバーへ配信済みのCKShare参加者側の記録)まで含めた完全な抹消は
/// このアプリの権限では行えないが、Appから作成・公開した自分のデータについては
/// ここで削除できる範囲を全て削除する。
enum AccountDeletionService {
    enum DeletionError: Error {
        case notSignedIn
    }

    static func deleteAccount(modelContext: ModelContext) async throws {
        guard let cloudKitManager = CloudKitManager.current else { throw DeletionError.notSignedIn }
        let container = cloudKitManager.container

        let profiles = (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard let user = UserProfile.current(from: profiles) else { throw DeletionError.notSignedIn }

        let sharingService = GroupSharingService(container: container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        let groups = (try? modelContext.fetch(FetchDescriptor<LaterGroup>())) ?? []
        for group in groups where group.isMember(user) {
            let isHost = group.ckZoneOwnerName == cloudKitManager.currentUserRecordName
            try? await sharingService.leaveGroup(group, currentUser: user, isHost: isHost)
            modelContext.delete(group)
        }

        // Public DBの公開ディレクトリ(検索・QRプロフィール共有用)から自分を消す。
        let directoryRecordID = CKRecord.ID(recordName: "userdir_\(user.id.uuidString)")
        try? await container.publicCloudDatabase.deleteRecord(withID: directoryRecordID)

        // World Laterへ自分が投稿した分をPublic DBから削除する。
        let worldPosts = (try? modelContext.fetch(FetchDescriptor<WorldPost>(predicate: #Predicate { $0.isOwnPost }))) ?? []
        for post in worldPosts {
            await WorldLaterService.deletePost(post)
        }

        // ローカルのSwiftDataストアを全て消去する。
        try? modelContext.delete(model: LaterPhoto.self)
        try? modelContext.delete(model: LaterVideo.self)
        try? modelContext.delete(model: LaterGroup.self)
        try? modelContext.delete(model: PhotoVote.self)
        try? modelContext.delete(model: BlockedUser.self)
        try? modelContext.delete(model: WorldPost.self)
        try? modelContext.delete(model: TodaysLaterSelection.self)
        try? modelContext.delete(model: UserProfile.self)
        try? modelContext.save()
    }
}
