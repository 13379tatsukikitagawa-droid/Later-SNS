import Photos
import UIKit

/// チェキ画像をPHPhotoLibraryへ保存するための薄いラッパー。addOnly権限(写真の追加のみ、
/// 既存ライブラリの閲覧は不要)でリクエストする。
@MainActor
enum PhotoLibrarySaver {
    enum SaveError: Error {
        case permissionDenied
    }

    static func save(_ image: UIImage) async throws {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            throw SaveError.permissionDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
