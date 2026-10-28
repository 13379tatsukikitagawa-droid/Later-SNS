import Foundation
import SwiftData
import Testing
@testable import Later_再度

/// 設定・プロフィール編集:写真の入れかわり待ちは1つだけ・取り消せる / 触覚の ON/OFF
@MainActor
struct SettingsEditTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test func 撮りなおすと待ちの写真が差しかわり_取り消せる() throws {
        let context = try makeContext()
        let profile = UserProfile(name: "ひかり", username: "later_test")
        context.insert(profile)
        let morning = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!

        ProfilePhotoDevelopment.storeRetake(Data([1]), for: profile, takenAt: morning, context: context)
        ProfilePhotoDevelopment.storeRetake(Data([2]), for: profile, takenAt: morning.addingTimeInterval(600), context: context)
        // 回数の制限なし。待ちは1つだけ(あとの1枚に差しかわる)
        #expect(profile.pendingProfileImageData == Data([2]))
        // 翌朝 9:00 に入れかわる
        let reveal = try #require(profile.pendingProfileImageRevealAt)
        #expect(Calendar.current.component(.hour, from: reveal) == 9)
        #expect(reveal > morning)

        ProfilePhotoDevelopment.cancelPending(for: profile, context: context)
        #expect(profile.pendingProfileImageData == nil)
        #expect(profile.pendingProfileImageRevealAt == nil)
    }

    @Test func 触覚の設定はアプリ全体で共有() {
        let before = AppHapticsSetting.isEnabled
        defer { AppHapticsSetting.isEnabled = before }
        AppHapticsSetting.isEnabled = false
        #expect(UserDefaults.standard.bool(forKey: ExposureHaptics.enabledDefaultsKey) == false)
        AppHapticsSetting.isEnabled = true
        #expect(AppHapticsSetting.isEnabled)
    }

    @Test func 約束は4つ() {
        #expect(LaterPromiseView.promises.count == 4)
    }
}
